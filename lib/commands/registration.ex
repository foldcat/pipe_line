defmodule PipeLine.Commands.Registration do
  @moduledoc """
  Handles registration of channels.
  """
  require Logger
  alias Nostrum.Api
  alias PipeLine.Database.Registration
  alias PipeLine.Database.Repo
  alias PipeLine.Relay.Webhook
  import IO.ANSI
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
    |> put_description("channel <##{chanid}> in this guild is successfully registered")
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
      [result] = q_result
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

  @spec insert_registration(Nostrum.Struct.Message) :: :ok
  def insert_registration(msg) do
    guild_id = msg.guild_id
    channel_id = msg.channel_id

    case query_chanid(Integer.to_string(guild_id)) do
      # chanid is registered
      # fail the registration
      {:ok, queried_chanid} ->
        Api.create_message(
          channel_id,
          embeds: [already_registered_embed(queried_chanid)],
          message_reference: %{message_id: msg.id}
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

            Webhook.get_webhook(Integer.to_string(channel_id))

            Api.create_message(channel_id,
              embeds: [registeration_success_embed(Integer.to_string(channel_id))],
              message_reference: %{message_id: msg.id}
            )

            log_registration(msg, true)

          {:error, _} ->
            Api.create_message(channel_id,
              embeds: [registeration_failure(Integer.to_string(channel_id))],
              message_reference: %{message_id: msg.id}
            )

            Logger.error("unknown error arising from registration attempt below:")
            log_registration(msg, false)
        end
    end
  end

  @spec registeration_rate_limit() :: Nostrum.Struct.Embed.t()
  def registeration_rate_limit do
    %Nostrum.Struct.Embed{}
    |> put_title("rate limited")
    |> put_description(
      "failed to register this guild as one guild may only register every 60 seconds"
    )
  end

  @spec warn_reg_limit_exceeded(Nostrum.Struct.Message) :: :ok
  def warn_reg_limit_exceeded(msg) do
    Logger.info("""
    not registering #{red() <> Integer.to_string(msg.guild_id) <> red()}
    as limit is exceeded
    """)

    case(Hammer.check_rate("reg-channel-warn#{msg.author.id}", 5000, 1)) do
      {:allow, _count} ->
        Api.create_message(
          msg.channel_id,
          embeds: [registeration_rate_limit()],
          message_reference: %{message_id: msg.id}
        )

      {:deny, _limit} ->
        nil
    end

    :ok
  end

  @spec register(Nostrum.Struct.Message) :: :ok
  def register(msg) do
    case(Hammer.check_rate("register-chan#{msg.guild_id}", 60_000, 1)) do
      {:allow, _count} ->
        insert_registration(msg)

      {:deny, _limit} ->
        warn_reg_limit_exceeded(msg)
    end

    :ok
  end
end
