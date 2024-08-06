defmodule PipeLine.Impl.Registration do
  @moduledoc """
  Handles registration of channels.
  """
  use Nostrum.Consumer
  require Logger
  alias PipeLine.Database.Repo
  alias PipeLine.Database.Registration
  alias Nostrum.Api
  import IO.ANSI
  alias PipeLine.Database.Repo
  alias PipeLine.Database.Registration
  import Ecto.Query

  @spec already_registered?(String.t()) :: boolean
  def already_registered?(guild_id) do
    query =
      from(r in Registration,
        where: r.guild_id == ^guild_id
      )

    Enum.empty?(Repo.all(query))
  end

  @spec log_registration(Nostrum.Struct.Message, boolean) :: :ok
  def log_registration(msg, success?) do
    log_msg =
      if success? do
        blue() <> "registering guild/channel" <> reset()
      else
        red() <> "failed to register" <> reset()
      end

    Logger.info("""
      #{log_msg}
      #{"guild id: " <> green() <> "#{msg.guild_id}" <> reset()}
      #{"channel id: " <> green() <> "#{msg.channel_id}" <> reset()}
    """)
  end

  @spec register(Nostrum.Struct.Message) :: :ok
  def register(msg) do
    guild_id = msg.guild_id
    channel_id = msg.channel_id

    if already_registered?(Integer.to_string(guild_id)) do
      case Repo.insert(%Registration{
             guild_id: Integer.to_string(guild_id),
             channel_id: Integer.to_string(channel_id)
           }) do
        {:ok, _} ->
          :ets.insert(:chan_cache, {Integer.to_string(channel_id)})
          Api.create_message(channel_id, "registered!")
          log_registration(msg, true)

        {:error, _} ->
          Api.create_message(channel_id, "fail to register")
          log_registration(msg, false)
      end
    else
      Api.create_message(channel_id, "guild is already registered")
      log_registration(msg, false)
    end

    :ok
  end
end
