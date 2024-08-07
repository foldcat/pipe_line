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
  import Nostrum.Struct.Embed

  @spec already_registered_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def already_registered_embed(chanid) do
    %Nostrum.Struct.Embed{}
    |> put_title("failed to register")
    |> put_description("channel <##{chanid}> in this guild is already registered")
  end

  @spec registeration_success_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def registeration_success_embed(chanid) do
    %Nostrum.Struct.Embed{}
    |> put_title("channel registration success!")
    |> put_description("channel <##{chanid}> in this guild is already registered")
  end

  @spec registeration_failure(String.t()) :: Nostrum.Struct.Embed.t()
  def registeration_failure(chanid) do
    %Nostrum.Struct.Embed{}
    |> put_title("unknown error")
    |> put_description("failed to register <##{chanid}>, please report this incident")
  end

  @doc """
  If channel id exists, returns {:ok, String.t()}
  else, {:error, nil}
  """
  @spec query_chanid(String.t()) :: {:ok, String.t()} | {:error, nil}
  def query_chanid(guild_id) do
    query =
      from r in Registration,
        where: r.guild_id == ^guild_id,
        select: r.channel_id

    q_result = Repo.all(query)

    if Enum.empty?(q_result) do
      {:error, nil}
    else
      # get the first item
      [result | _] = q_result
      {:ok, result}
    end
  end

  @spec log_registration(Nostrum.Struct.Message, boolean) :: :ok
  def log_registration(msg, success?) do
    bottom_message =
      """
      #{"guild id: " <> green() <> "#{msg.guild_id}" <> reset()}
      #{"channel id: " <> green() <> "#{msg.channel_id}" <> reset()}
      """

    if success? do
      Logger.info("""
        #{blue() <> "registering guild/channel" <> reset()}
        #{bottom_message}
      """)
    else
      Logger.error("""
        #{red() <> "failed to register" <> reset()}
        #{bottom_message}
      """)
    end
  end

  @spec register(Nostrum.Struct.Message) :: :ok
  def register(msg) do
    guild_id = msg.guild_id
    channel_id = msg.channel_id

    case query_chanid(Integer.to_string(guild_id)) do
      # chanid is registered
      # fail the registration
      {:ok, queried_chanid} ->
        Api.create_message(
          channel_id,
          embeds: [already_registered_embed(queried_chanid)]
        )

        log_registration(msg, false)

      # chanid is not registered
      # lets make the registration succeed
      {:error, _} ->
        case Repo.insert(%Registration{
               guild_id: Integer.to_string(guild_id),
               channel_id: Integer.to_string(channel_id)
             }) do
          {:ok, _} ->
            :ets.insert(:chan_cache, {Integer.to_string(channel_id)})

            Api.create_message(channel_id,
              embeds: [registeration_success_embed(Integer.to_string(channel_id))]
            )

            log_registration(msg, true)

          {:error, _} ->
            Api.create_message(channel_id,
              embeds: [registeration_failure(Integer.to_string(channel_id))]
            )

            Logger.error("unknown error arising from registration attempt below:")
            log_registration(msg, false)
        end
    end

    :ok
  end
end
