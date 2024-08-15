defmodule PipeLine.Relay.Delete do
  @moduledoc """
  Handles delection of messages.
  """

  require Logger
  import IO.ANSI
  alias Nostrum.Api
  alias PipeLine.Relay.ReplyCache

  @spec delete_impl(String.t()) :: :ok
  def delete_impl(id) do
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
  end

  @spec delete(String.t(), String.t()) :: :ok
  def delete(id, channel_id) do
    if not Enum.empty?(
         :ets.lookup(
           :chan_cache,
           channel_id
         )
       ) do
      case(Hammer.check_rate("delete-msg#{id}", 10_000, 1)) do
        {:allow, _count} ->
          delete_impl(id)

        {:deny, _limit} ->
          Logger.info("""
          not deleting #{red() <> id <> red()}
          as limit is exceeded
          """)
      end

      :ok
    end
  end
end
