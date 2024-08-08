defmodule PipeLine do
  @moduledoc """
  Spawn up a base Supervisor.
  """
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("starting")

    children = [
      PipeLine.Database.Repo,
      PipeLine.Core,
      PipeLine.Init
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule PipeLine.Init do
  @moduledoc """
  Init function that runs on start.
  Mainly loads database into cache.
  """
  use GenServer
  import Ecto.Query
  import IO.ANSI
  alias PipeLine.Database.Registration
  alias PipeLine.Database.Repo
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info(blue() <> "starting ets" <> reset())

    # we cache channel ids registered
    :ets.new(:chan_cache, [:set, :public, :named_table])

    Logger.info(blue() <> "ets started, table created!" <> reset())

    query =
      from r in Registration,
        select: r.channel_id

    chan_ids = Repo.all(query)

    Logger.info("""
      #{blue() <> "loading channel_ids" <> reset()}
      #{Enum.join(chan_ids, "\n")}
    """)

    Enum.each(chan_ids, fn id ->
      :ets.insert(:chan_cache, {id})
    end)

    {:ok, nil}
  end
end

defmodule PipeLine.Core do
  @moduledoc """
  Handles event sent by Discord.
  """
  use Nostrum.Consumer
  require Logger
  alias PipeLine.Commands.Cache
  alias PipeLine.Commands.Clist
  alias PipeLine.Commands.Ping
  alias PipeLine.Commands.Registration
  alias PipeLine.Commands.Unregister
  alias PipeLine.Relay.Core

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    Task.start(fn -> Core.relay_msg(msg) end)

    case msg.content do
      ">! ping" ->
        Ping.ping(msg)

      ">! register" ->
        Registration.register(msg)

      ">! unregister" ->
        Unregister.unregister(msg)

      ">! clist" ->
        Clist.send_list(msg)

      ">! cached?" ->
        Cache.cached?(msg)

      _ ->
        :noop
    end
  end
end
