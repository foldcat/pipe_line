# Copyright 2024 foldcat
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule PipeLine.Commands.Registration do
  @moduledoc """
  Handles registration of channels.
  """
  require Logger
  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Cache.MemberCache
  alias Nostrum.Struct.Guild.Member
  alias PipeLine.Commands.Info
  alias PipeLine.Database.Registration
  alias PipeLine.Database.Repo
  alias PipeLine.Relay.Webhook
  import IO.ANSI
  import Ecto.Query
  import Nostrum.Struct.Embed

  @spec no_perm_embed() :: Nostrum.Struct.Embed.t()
  def no_perm_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("no permissions")
    |> put_description("you need :manage_channels permission")
  end

  @spec has_permission(integer, integer) :: boolean
  def has_permission(guild_id, member_id) do
    {:ok, guild} = GuildCache.get(guild_id)
    {:ok, member} = MemberCache.get(guild_id, member_id)
    member_perms = Member.guild_permissions(member, guild)
    :manage_channels in member_perms
  end

  @spec warn_permission(Nostrum.Struct.Message) :: :ok
  def warn_permission(msg) do
    Api.create_message(
      msg.channel_id,
      embeds: [no_perm_embed()],
      message_reference: %{message_id: msg.id}
    )

    :ok
  end

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

  @spec insert_registration_impl(Nostrum.Struct.Message) :: :ok
  def insert_registration_impl(msg) do
    case(Hammer.check_rate("register-chan#{msg.guild_id}", 60_000, 1)) do
      {:allow, _count} ->
        guild_id = msg.guild_id
        channel_id = msg.channel_id

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

            Info.send_info(msg)

            log_registration(msg, true)

          {:error, _} ->
            Api.create_message(channel_id,
              embeds: [registeration_failure(Integer.to_string(channel_id))],
              message_reference: %{message_id: msg.id}
            )

            Logger.error("unknown error arising from registration attempt below:")
            log_registration(msg, false)
        end

      {:deny, _limit} ->
        warn_reg_limit_exceeded(msg)
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
        insert_registration_impl(msg)
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
    if has_permission(msg.guild_id, msg.author.id) do
      insert_registration(msg)
    else
      warn_permission(msg)
    end

    :ok
  end
end
