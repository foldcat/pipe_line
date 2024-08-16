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
    - delete and edit may not work on old messages
    - message relayed may be altered in-transport
    - this message may be changed without prior notice
    - relaying any messages means you have understood the rules (see `>! rules`)
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
