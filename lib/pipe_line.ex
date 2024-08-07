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
  require Logger
  alias PipeLine.Database.Repo
  alias PipeLine.Database.Registration
  import Ecto.Query
  import IO.ANSI

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
  alias PipeLine.Cache
  alias PipeLine.Ping
  alias PipeLine.Registration
  alias PipeLine.Clist

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      ">! ping" ->
        Ping.ping(msg)

      ">! register" ->
        Registration.register(msg)

      ">! clist" ->
        Clist.send_list(msg)

      ">! cached?" ->
        Cache.cached?(msg)

      _ ->
        :noop
    end
  end
end
