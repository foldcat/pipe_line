defmodule PipeLine.Impl.Cache do
  @moduledoc """
  module that checks if individual 
  channel is cached
  """
  use Nostrum.Consumer
  alias Nostrum.Api

  @spec cached?(Nostrum.Struct.Message) :: :ok
  def cached?(msg) do
    query_result =
      :ets.lookup(
        :chan_cache,
        Integer.to_string(msg.channel_id)
      )

    if Enum.empty?(query_result) do
      Api.create_message(msg.channel_id, "this channel is not cached")
    else
      Api.create_message(msg.channel_id, "this channel is cached")
    end

    :ok
  end
end
