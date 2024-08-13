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

    :ok
  end

  @spec update_msg(Nostrum.Struct.Message, Nostrum.Struct.Message) :: :ok
  def update_msg(_oldmsg, newmsg) do
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

    :ok
  end
end
