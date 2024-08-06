defmodule PipeLine.Impl.Clist do
  @moduledoc """
  Sends out a list of every registered channels.
  """
  use Nostrum.Consumer
  require Logger
  alias PipeLine.Database.Repo
  alias PipeLine.Database.Registration
  import Ecto.Query
  alias Nostrum.Api

  @spec registration_to_string(Registration) :: String.t()
  def registration_to_string(reg) do
    """
    {:guild_id #{reg.guild_id}
     :channel_id #{reg.channel_id}}
    """
  end

  @spec send_list(Nostrum.Struct.Message) :: :ok
  def send_list(msg) do
    query = from(Registration)

    formatted =
      Repo.all(query)
      |> Enum.map_join("", &registration_to_string(&1))

    Api.create_message(msg.channel_id, formatted)

    :ok
  end
end
