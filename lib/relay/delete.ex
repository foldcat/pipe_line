defmodule PipeLine.Relay.Delete do
  @moduledoc """
  Handles delection of messages.
  """

  require Logger
  import IO.ANSI
  alias Nostrum.Api
  alias PipeLine.Relay.ReplyCache

  @spec delete(String.t()) :: :ok
  def delete(id) do
    case(Hammer.check_rate("delete-msg#{id}", 10_000, 1)) do
      {:allow, _count} ->
        targets = ReplyCache.get_messages(id)

        if not (targets == nil) do
          Enum.each(
            targets,
            fn ws_msg ->
              Api.delete_message(
                String.to_integer(ws_msg.channel_id),
                String.to_integer(ws_msg.message_id)
              )
            end
          )

          Logger.info("""
          deleted message of id #{red() <> id <> reset()}
          """)
        end

      {:deny, _limit} ->
        Logger.info("""
        not deleting #{red() <> id <> red()}
        as limit is exceeded
        """)
    end

    :ok
  end
end
