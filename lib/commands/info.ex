defmodule PipeLine.Commands.Info do
  @moduledoc """
  Information.
  """
  import Nostrum.Struct.Embed
  alias Nostrum.Api

  def info_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("info")
    |> put_description("""
    pipe-line is a Discord bot that relays messages to multiple other Discord channels

    - we only relay ASCII symbols
    - we only relay a subset of built in emoji
    - some words are implicitly censored
    - delete and edit does not work on old messages
    """)
  end

  @spec send_info(Nostrum.Struct.Message) :: :ok
  def send_info(msg) do
    Api.create_message(msg.channel_id,
      embeds: [info_embed()],
      message_reference: %{message_id: msg.id}
    )

    :ok
  end
end
