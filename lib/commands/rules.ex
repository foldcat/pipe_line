defmodule PipeLine.Commands.Rules do
  @moduledoc """
  The rules.
  """

  import Nostrum.Struct.Embed
  alias Nostrum.Api

  @spec get_rules() :: list(String.t())
  def get_rules do
    Application.fetch_env!(:pipe_line, :rules)
  end

  @spec rules_embed() :: Nostrum.Struct.Embed.t()
  def rules_embed do
    rules =
      get_rules()
      |> Enum.with_index()
      |> Enum.map(fn {rule, index} ->
        {rule, index + 1}
      end)
      |> Enum.map_join("\n", fn {rule, index} ->
        "#{index}. #{rule}"
      end)
      |> String.trim()

    %Nostrum.Struct.Embed{}
    |> put_title("rules")
    |> put_description(rules)
  end

  @spec send_rules(Nostrum.Struct.Message) :: :ok
  def send_rules(msg) do
    Api.create_message(msg.channel_id,
      embeds: [rules_embed()],
      message_reference: %{message_id: msg.id}
    )

    :ok
  end
end
