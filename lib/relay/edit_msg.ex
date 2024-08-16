defmodule PipeLine.Relay.EditMsg do
  @moduledoc """
  Handles editing of messages.
  """
  alias Nostrum.Api
  alias PipeLine.Relay.RelayCache
  require Logger
  import IO.ANSI
  import Nostrum.Struct.Embed

  @spec edit_ratelimit_exceeded() :: Nostrum.Struct.Embed.t()
  def edit_ratelimit_exceeded do
    %Nostrum.Struct.Embed{}
    |> put_title("rate limit exceeded")
    |> put_description("you have exceeded the 1 edit per 5 seconds rate limit")
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

  @spec update_msg_impl(Nostrum.Struct.Message) :: :ok
  def update_msg_impl(newmsg) do
    author_id = newmsg.author.id

    case(Hammer.check_rate("edit-msg#{author_id}", 10_000, 1)) do
      {:allow, _count} ->
        targets = RelayCache.get_messages(Integer.to_string(newmsg.id))

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
  end

  @spec update_msg(Nostrum.Struct.Message, Nostrum.Struct.Message) :: :ok
  def update_msg(_oldmsg, newmsg) do
    if not Enum.empty?(
         :ets.lookup(
           :chan_cache,
           Integer.to_string(newmsg.channel_id)
         )
       ) do
      update_msg_impl(newmsg)
    end

    :ok
  end
end
