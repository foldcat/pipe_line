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

defmodule PipeLine.Commands.Clist do
  @moduledoc """
  Sends out a list of every registered channels.
  """
  require Logger
  alias Nostrum.Api
  import Nostrum.Struct.Embed
  alias PipeLine.Database.Registration
  alias PipeLine.Database.Repo
  require Ecto.Query
  alias Ecto.Query

  @spec registration_to_string(Registration) :: String.t()
  def registration_to_string(reg) do
    """
    {:guild_id #{reg.guild_id}
     :channel_id #{reg.channel_id}}
    """
  end

  @spec send_list(Nostrum.Struct.Message) :: :ok
  def send_list(msg) do
    query = Query.from(Registration)

    formatted =
      String.trim("""
      ```clojure
      #{Repo.all(query) |> Enum.map_join("", &registration_to_string(&1))}
      ```
      """)

    clist_embed =
      %Nostrum.Struct.Embed{}
      |> put_title("clist")
      |> put_description(formatted)

    Api.create_message(msg.channel_id,
      embeds: [clist_embed],
      message_reference: %{message_id: msg.id}
    )

    :ok
  end
end
