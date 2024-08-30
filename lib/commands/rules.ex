# Copyright 2024 foldcat
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule PipeLine.Commands.Rules do
  @moduledoc """
  The rules.
  """

  import Nostrum.Struct.Embed
  alias Nostrum.Api

  @rules Application.compile_env!(:pipe_line, :rules)

  @spec rules_embed() :: Nostrum.Struct.Embed.t()
  def rules_embed do
    rules =
      @rules
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
