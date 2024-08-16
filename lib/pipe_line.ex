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
  alias PipeLine.Database.Admin
  alias PipeLine.Database.Ban
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
    # and the admins
    :ets.new(:admin, [:set, :public, :named_table])
    # and the bans
    :ets.new(:ban, [:set, :public, :named_table])

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

    query_bans = from(Ban)

    bans = Repo.all(query_bans)

    Enum.each(bans, fn banned ->
      :ets.insert(
        :ban,
        {banned.user_id}
      )
    end)

    query_admin = from(Admin)

    admins = Repo.all(query_admin)

    Enum.each(admins, fn admin ->
      :ets.insert(
        :admin,
        {admin.user_id}
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
      PipeLine.Relay.RelayCache,
      PipeLine.Relay.Delete.Lock,
      PipeLine.Commands.Ban.OwnerCache
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
  alias PipeLine.Commands.Admin
  alias PipeLine.Commands.Ban
  alias PipeLine.Commands.BulkDelete
  alias PipeLine.Commands.Cache
  alias PipeLine.Commands.Clist
  alias PipeLine.Commands.Help
  alias PipeLine.Commands.Info
  alias PipeLine.Commands.Ping
  alias PipeLine.Commands.Registration
  alias PipeLine.Commands.Rules
  alias PipeLine.Commands.Unregister
  alias PipeLine.Relay.Core
  alias PipeLine.Relay.Delete
  alias PipeLine.Relay.EditMsg

  # credo:disable-for-next-line
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    Task.start(fn -> Core.relay_msg(msg) end)

    if msg.author.bot == nil do
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

        ">! admin?" ->
          Admin.am_i_admin?(msg)

        ">! is banned" <> _ ->
          Ban.banned_command(msg)

        ">! getowner" ->
          Ban.get_owner(msg)

        ">! help" ->
          Help.help(msg)

        ">! rules" ->
          Rules.send_rules(msg)

        ">! info" ->
          Info.send_info(msg)

        # admin exclusive

        ">! ban" <> _ ->
          # credo:disable-for-next-line
          Admin.permcheck(msg, fn -> Ban.ban(msg) end)

        ">! unban" <> _ ->
          # credo:disable-for-next-line
          Admin.permcheck(msg, fn -> Ban.unban_command(msg) end)

        ">! purge" <> _ ->
          # credo:disable-for-next-line
          Admin.permcheck(msg, fn -> BulkDelete.bulk_delete_cmd(msg) end)

        _ ->
          :noop
      end
    end
  end

  def handle_event({:MESSAGE_UPDATE, {oldmsg, newmsg}, _ws_state}) do
    if newmsg.author.bot == nil do
      Task.start(fn -> EditMsg.update_msg(oldmsg, newmsg) end)
    end
  end

  def handle_event({:MESSAGE_DELETE, msg, _ws_state}) do
    Task.start(fn ->
      if not Delete.Lock.engaged?() do
        Delete.delete(
          Integer.to_string(msg.id),
          Integer.to_string(msg.channel_id)
        )
      end
    end)
  end
end
