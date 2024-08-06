defmodule PipeLine.Impl.Core do
  @moduledoc """
  Handles event sent by Discord.
  """
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Api

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      ">! ping" ->
        pid =
          self()
          |> :erlang.pid_to_list()
          |> to_string()

        Logger.info("got ping")
        Api.create_message(msg.channel_id, "node online, pid #{pid}")

      ">! register" ->
        Logger.info("registering guild/channel")
        guild_id = msg.guild_id
        chan_id = msg.channel_id
        Api.create_message(chan_id, "registering on channel <\##{chan_id}> in server #{guild_id}")

      _ ->
        :noop
    end
  end
end
