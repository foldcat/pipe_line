defmodule PipeLine.Impl.Core do
  @moduledoc """
  Handles event sent by Discord.
  """
  use Nostrum.Consumer
  require Logger
  alias PipeLine.Impl.Registration
  alias PipeLine.Impl.Clist
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
        Registration.register(msg)

      ">! clist" ->
        Clist.send_list(msg)

      _ ->
        :noop
    end
  end
end
