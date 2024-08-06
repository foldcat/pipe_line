defmodule PipeLine.Impl.Registration do
  @moduledoc """
  Handles registration of channels.
  """
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Api

  @spec register(Nostrum.Struct.Message) :: nil
  def register(msg) do
    Logger.info("registering guild/channel")
    guild_id = msg.guild_id
    chan_id = msg.channel_id
    Api.create_message(chan_id, "registering on channel <\##{chan_id}> in server #{guild_id}")
  end
end
