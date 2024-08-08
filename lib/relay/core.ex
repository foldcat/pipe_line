defmodule PipeLine.Relay.Core do
  @moduledoc """
  Process that handles relaying messages 
  to multiple Discord channels.
  """

  require Logger
  import IO.ANSI

  @doc """
  pipe_single_msg takes a message object and sends it 
  to every channel that is registered BUT the channel 
  id supplied to from_channel argument
  """
  @spec pipe_msg(Nostrum.Struct.Message, String.t()) :: :ok
  def pipe_msg(msg, from_channel) do
    cache_lookup = :ets.tab2list(:chan_cache)

    Enum.each(cache_lookup, fn {chanid} ->
      # do not relay message back to the original channel
      if not (Integer.to_string(msg.channel_id) == from_channel) do
        Logger.info("""
          relaying message #{blue() <> Integer.to_string(msg.id) <> reset()}
          to channel #{blue() <> chanid <> reset()} 
          from channel #{blue() <> from_channel <> reset()}
        """)
      end

      nil
    end)

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
    if not Enum.empty?(cache_lookup) do
      Logger.info("""
      relaying message of id 
      #{blue() <> Integer.to_string(msg.id) <> reset()}
      """)

      pipe_msg(msg, Integer.to_string(msg.channel_id))
    end

    :ok
  end
end
