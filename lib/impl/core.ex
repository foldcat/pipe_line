defmodule PipeLine.Impl.Core do
  @moduledoc """
  Handles event sent by Discord.
  """
  use Nostrum.Consumer
  require Logger
  alias PipeLine.Impl.Ping
  alias PipeLine.Impl.Registration
  alias PipeLine.Impl.Clist

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      ">! ping" ->
        Ping.ping(msg)

      ">! register" ->
        Registration.register(msg)

      ">! clist" ->
        Clist.send_list(msg)

      _ ->
        :noop
    end
  end
end
