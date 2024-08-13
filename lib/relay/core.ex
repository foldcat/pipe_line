defmodule PipeLine.Relay.Core do
  @moduledoc """
  Process that handles relaying messages 
  to multiple Discord channels.
  """
  alias Nostrum.Api
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
          Logger.info("""
            relaying message #{blue() <> Integer.to_string(msg.id) <> reset()}
            to channel #{blue() <> chanid <> reset()} 
            from channel #{blue() <> from_channel <> reset()}
          """)

          Webhook.relay_message(msg, chanid)
        end
      end)
      |> Enum.filter(fn item -> item != nil end)

    ReplyCache.cache_message(msg, webhook_ids)

    :ok
  end

  @spec relay_msg(Nostrum.Struct.Message) :: :ok
  def relay_msg(msg) do
    author_id = msg.author.id

    case(Hammer.check_rate("relay-msg#{author_id}", 5000, 2)) do
      {:allow, _count} ->
        cache_lookup =
          :ets.lookup(
            :chan_cache,
            Integer.to_string(msg.channel_id)
          )

        # said message is inside registered channel list
        if not Enum.empty?(cache_lookup) and msg.author.bot != true do
          Logger.info("""
          relaying message of id 
          #{blue() <> Integer.to_string(msg.id) <> reset()}
          """)

          pipe_msg(msg, Integer.to_string(msg.channel_id))
        end

      {:deny, _limit} ->
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
    end

    :ok
  end

  @spec update_msg(Nostrum.Struct.Message, Nostrum.Struct.Message) :: :ok
  def update_msg(_oldmsg, newmsg) do
    author_id = newmsg.author.id

    case(Hammer.check_rate("edit-msg#{author_id}", 10000, 1)) do
      {:allow, _count} ->
        targets = ReplyCache.get_messages(Integer.to_string(newmsg.id))

        IO.puts(red() <> Kernel.inspect(targets) <> reset())

        Enum.each(
          targets,
          fn ws_msg ->
            [{_chanid, webhook_info}] =
              :ets.lookup(:webhook_cache, ws_msg.channel_id)

            Logger.info("""
              relaying edit #{blue() <> Integer.to_string(newmsg.id) <> reset()}
            """)

            Api.edit_webhook_message(
              webhook_info.webhook_id,
              webhook_info.webhook_token,
              ws_msg.message_id,
              %{
                content: newmsg.content
              }
            )

            Logger.info(blue() <> "edit relayed" <> reset())
          end
        )

      {:deny, _limit} ->
        Logger.info("""
        not editing #{red() <> Integer.to_string(newmsg.id) <> red()}
        as limit is exceeded
        """)

        case(Hammer.check_rate("edit-msg-warn#{author_id}", 10000, 1)) do
          {:allow, _count} ->
            Api.create_message(
              newmsg.channel_id,
              embeds: [edit_ratelimit_exceeded()],
              message_reference: %{message_id: newmsg.id}
            )

          {:deny, _limit} ->
            nil
        end
    end

    :ok
  end
end
