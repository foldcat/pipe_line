defmodule PipeLine.Commands.Ping do
  @moduledoc """
  Handles the ping command.
  """
  require Logger
  alias Nostrum.Api
  import Nostrum.Struct.Embed

  @spec ping(Nostrum.Struct.Message) :: :ok
  def ping(msg) do
    pid =
      self()
      |> :erlang.pid_to_list()
      |> to_string()

    ping_embed =
      %Nostrum.Struct.Embed{}
      |> put_title("ping")
      |> put_description("node online, pid `#{pid}`")

    Logger.info("got ping")

    Api.create_message(msg.channel_id,
      embeds: [ping_embed],
      message_reference: %{message_id: msg.id}
    )

    :ok
  end
end
