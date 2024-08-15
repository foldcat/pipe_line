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
