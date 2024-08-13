defmodule PipeLine do
  @moduledoc """
  Spawn up the base Supervisor.
  """
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("starting")

    # start database connection and the init process
    children = [
      PipeLine.Database.Repo,
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
  alias PipeLine.Database.Webhooks
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("""
      starting init process
      pid: #{red() <> Kernel.inspect(self()) <> reset()}
    """)

    Logger.info(blue() <> "starting ets" <> reset())

    # we cache channel ids registered
    :ets.new(:chan_cache, [:set, :public, :named_table])
    # and the webhooks
    :ets.new(:webhook_cache, [:set, :public, :named_table])

    Logger.info(blue() <> "ets started, table created!" <> reset())

    # cache all the registered channels

    query_chanid =
      from r in Registration,
        select: r.channel_id

    chan_ids = Repo.all(query_chanid)

    Logger.info("""
      #{blue() <> "loading channel_ids" <> reset()}
      #{Enum.join(chan_ids, "\n")}
    """)

    Enum.each(chan_ids, fn id ->
      :ets.insert(:chan_cache, {id})
    end)

    # cache all the webhooks

    query_webhook = from(Webhooks)

    webhooks = Repo.all(query_webhook)

    Enum.each(webhooks, fn wh ->
      :ets.insert(
        :webhook_cache,
        {wh.channel_id, %{webhook_id: wh.webhook_id, webhook_token: wh.webhook_token}}
      )
    end)

    start_service()

    {:ok, nil}
  end

  @doc """
  Fires up the main handler.
  Is ran after `init`.
  """
  def start_service do
    Logger.info(green() <> "starting service" <> reset())

    children = [
      PipeLine.Core,
      PipeLine.Relay.Censor,
      PipeLine.Relay.ReplyCache
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

    Logger.info(green() <> "pipe-line ready" <> reset())
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

  def handle_event({:MESSAGE_UPDATE, {oldmsg, newmsg}, _ws_state}) do
    if newmsg.author.bot == nil do
      Task.start(fn -> Core.update_msg(oldmsg, newmsg) end)
    end
  end
end
