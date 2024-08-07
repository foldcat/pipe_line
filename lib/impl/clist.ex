defmodule PipeLine.Impl.Clist do
  @moduledoc """
  Sends out a list of every registered channels.
  """
  use Nostrum.Consumer
  require Logger
  alias PipeLine.Database.Repo
  alias PipeLine.Database.Registration
  require Ecto.Query
  alias Nostrum.Api
  alias Ecto.Query
  import Nostrum.Struct.Embed

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

    Api.create_message(msg.channel_id, embeds: [clist_embed])

    :ok
  end
end
