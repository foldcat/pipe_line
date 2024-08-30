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

defmodule PipeLine.Commands.Help do
  @moduledoc """
  Sends out a help command.
  """
  alias Nostrum.Api
  import Nostrum.Struct.Embed

  @spec help_embed() :: Nostrum.Struct.Embed.t()
  def help_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("pipe-line manual")
    |> put_description("""
      ### common commands
      `>! register`  setup relay to this channel
      `>! unregister`  disable relay to this channel
      `>! admin?`  am I an admin 
      `>! is banned <userid>`  is <userid> banned 
      `>! getowner`  reply to a webhook message to see it's owner's id, only works on recent messages
      `>! info`  display info about this bot 
      `>! rules`  display rules
      `>! help`  prints this manual
      
      ### admin commands
      `>! ban <userid>`  permabans <userid> 
      `>! unban <userid>`  unbans <userid>
      `>! purge <amount>`  bulk delete <amount> recent messages, where <amount> must be greater than 1
      
      ### debug commands 
      `>! ping`  see if this bot is online 
      `>! clist`  see all the current registered channels 
      `>! cached?`  is this channel cached 
    """)
  end

  @spec help(Nostrum.Struct.Message) :: :ok
  def help(msg) do
    Api.create_message(msg.channel_id,
      embeds: [help_embed()],
      message_reference: %{message_id: msg.id}
    )

    :ok
  end
end
