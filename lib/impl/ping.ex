defmodule PipeLine.Impl.Ping do
  @moduledoc """
  Handles the ping command.
  """
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Api

  @spec ping(Nostrum.Struct.Message) :: :ok
  def ping(msg) do
    pid =
      self()
      |> :erlang.pid_to_list()
      |> to_string()

    Logger.info("got ping")
    Api.create_message(msg.channel_id, "node online, pid #{pid}")

    :ok
  end
end
