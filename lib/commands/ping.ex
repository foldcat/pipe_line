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
