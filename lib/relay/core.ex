defmodule PipeLine.Relay.Core do
  @moduledoc """
  Process that handles relaying messages 
  to multiple Discord channels.
  """
  alias Nostrum.Api
  alias PipeLine.Commands.Ban
  alias PipeLine.Relay.Censor
  alias PipeLine.Relay.ReplyCache
  alias PipeLine.Relay.Webhook
  require Logger
  import IO.ANSI
  import Nostrum.Struct.Embed

  @spec relay_ratelimit_exceeded() :: Nostrum.Struct.Embed.t()
  def relay_ratelimit_exceeded do
    %Nostrum.Struct.Embed{}
    |> put_title("rate limit exceeded")
    |> put_description("you have exceeded the 2 messages per 5 seconds rate limit")
  end

  @spec edit_ratelimit_exceeded() :: Nostrum.Struct.Embed.t()
  def edit_ratelimit_exceeded do
    %Nostrum.Struct.Embed{}
    |> put_title("rate limit exceeded")
    |> put_description("you have exceeded the 1 edit per 5 seconds rate limit")
  end

  @spec warn_relay_limit_exceeded(Nostrum.Struct.Message, String.t()) :: :ok
  def warn_relay_limit_exceeded(msg, author_id) do
    Logger.info("""
    not relaying #{red() <> Integer.to_string(msg.id) <> red()}
    as limit is exceeded
    """)

    case(Hammer.check_rate("relay-msg-warn#{author_id}", 5000, 1)) do
      {:allow, _count} ->
        Api.create_message(
          msg.channel_id,
          embeds: [relay_ratelimit_exceeded()],
          message_reference: %{message_id: msg.id}
        )

      {:deny, _limit} ->
        nil
    end

    :ok
  end

  @spec warn_edit_limit_exceeded(Nostrum.Struct.Message, integer) :: :ok
  def warn_edit_limit_exceeded(msg, author_id) do
    Logger.info("""
    not editing #{red() <> Integer.to_string(msg.id) <> red()}
    as limit is exceeded
    """)

    case(Hammer.check_rate("edit-msg-warn#{author_id}", 10_000, 1)) do
      {:allow, _count} ->
        Api.create_message(
          msg.channel_id,
          embeds: [edit_ratelimit_exceeded()],
          message_reference: %{message_id: msg.id}
        )

      {:deny, _limit} ->
        nil
    end

    :ok
  end

  @doc """
  `pipe_single_msg` takes a message object and sends it 
  to every channel that is registered BUT the channel 
  id supplied to from_channel argument.
  """
  @spec pipe_msg(Nostrum.Struct.Message, String.t()) :: :ok
  def pipe_msg(msg, from_channel) do
    cache_lookup = :ets.tab2list(:chan_cache)

    webhook_ids =
      Enum.map(cache_lookup, fn {chanid} ->
        # do not relay message back to the original channel
        if chanid == from_channel do
          nil
        else
          Logger.debug("""
            relaying message #{blue() <> Integer.to_string(msg.id) <> reset()}
            to channel #{blue() <> chanid <> reset()} 
            from channel #{blue() <> from_channel <> reset()}
          """)

          santized_content =
            msg.content
            |> Censor.replace_unicode()
            |> Censor.sanitize()

          Webhook.relay_message(msg, chanid, santized_content)
        end
      end)
      |> Enum.filter(fn item -> item != nil end)

    ReplyCache.cache_message(msg, webhook_ids)

    :ok
  end

  @spec relay_all(Nostrum.Struct.Message, list({String.t()})) :: :ok
  def relay_all(msg, cache_lookup) do
    # said message is inside registered channel list
    if not Enum.empty?(cache_lookup) do
      pipe_msg(msg, Integer.to_string(msg.channel_id))

      Logger.info("""
      relayed #{blue() <> msg.author.global_name <> reset()}'s message:
      #{green() <> msg.content <> reset()}
      """)
    end

    :ok
  end

  @spec relay_msg(Nostrum.Struct.Message) :: :ok
  def relay_msg(msg) do
    author_id = Integer.to_string(msg.author.id)

    if msg.author.bot == nil and not Ban.banned?(author_id) do
      case(Hammer.check_rate("relay-msg#{author_id}", 5000, 2)) do
        {:allow, _count} ->
          cache_lookup =
            :ets.lookup(
              :chan_cache,
              Integer.to_string(msg.channel_id)
            )

          # said message is inside registered channel list
          relay_all(msg, cache_lookup)

        {:deny, _limit} ->
          warn_relay_limit_exceeded(msg, author_id)
      end
    end

    :ok
  end

  @spec update_msg(Nostrum.Struct.Message, Nostrum.Struct.Message) :: :ok
  def update_msg(_oldmsg, newmsg) do
    author_id = newmsg.author.id

    case(Hammer.check_rate("edit-msg#{author_id}", 10_000, 1)) do
      {:allow, _count} ->
        targets = ReplyCache.get_messages(Integer.to_string(newmsg.id))

        Enum.each(
          targets,
          fn ws_msg ->
            [{_chanid, webhook_info}] =
              :ets.lookup(:webhook_cache, ws_msg.channel_id)

            Api.edit_webhook_message(
              webhook_info.webhook_id,
              webhook_info.webhook_token,
              ws_msg.message_id,
              %{
                content: newmsg.content
              }
            )
          end
        )

        Logger.info("""
        relayed #{blue() <> newmsg.author.global_name <> reset()}'s edit:
        #{green() <> newmsg.content <> reset()}
        """)

      {:deny, _limit} ->
        warn_edit_limit_exceeded(newmsg, author_id)
    end

    :ok
  end
end
