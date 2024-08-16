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

defmodule PipeLine.Commands.Ban do
  @moduledoc """
  Ban an user.
  """

  require Logger
  import Ecto.Query
  import Nostrum.Struct.Embed
  import IO.ANSI
  alias Nostrum.Api
  alias PipeLine.Commands.Ban.OwnerCache
  alias PipeLine.Database.Ban
  alias PipeLine.Database.Repo

  @spec banned?(String.t()) :: boolean
  def banned?(target) do
    not Enum.empty?(:ets.lookup(:ban, target))
  end

  @spec permabanned_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def permabanned_embed(target) do
    %Nostrum.Struct.Embed{}
    |> put_title("permabanned")
    |> put_description(target)
  end

  @spec already_banned_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def already_banned_embed(target) do
    %Nostrum.Struct.Embed{}
    |> put_title("already banned")
    |> put_description(target <> " is already banned")
  end

  @spec permaban(Nostrum.Struct.Message) :: :ok
  def permaban(msg) do
    target =
      String.split(msg.content)
      |> Enum.at(2)
      |> String.trim()

    if banned?(target) do
      Api.create_message(
        msg.channel_id,
        embeds: [already_banned_embed(target)],
        message_reference: %{message_id: msg.id}
      )

      Logger.info("""
      failed to ban #{red() <> target <> reset()}
      as they are already banned
      """)
    else
      Repo.insert(%Ban{
        user_id: target
      })

      :ets.insert(:ban, {target})

      Api.create_message(
        msg.channel_id,
        embeds: [permabanned_embed(target)],
        message_reference: %{message_id: msg.id}
      )

      Logger.info("""
      permabanned #{red() <> target <> reset()}
      """)

      :ok
    end
  end

  @spec ban(Nostrum.Struct.Message) :: :ok
  def ban(msg) do
    input = String.split(msg.content)

    if length(input) == 3 do
      permaban(msg)
    end

    :ok
  end

  @spec unban(String.t()) :: :ok
  def unban(id) do
    query =
      from b in Ban,
        where: b.user_id == ^id,
        select: b.user_id

    Repo.delete_all(query)
    :ets.delete(:ban, id)

    :ok
  end

  @spec unban_success_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def unban_success_embed(id) do
    %Nostrum.Struct.Embed{}
    |> put_title("success")
    |> put_description(id <> " is unbanned")
  end

  @spec unban_fail_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def unban_fail_embed(id) do
    %Nostrum.Struct.Embed{}
    |> put_title("fail")
    |> put_description(id <> " is not banned")
  end

  @spec unban_command(Nostrum.Struct.Message) :: :ok
  def unban_command(msg) do
    target =
      String.split(msg.content)
      |> Enum.at(2)
      |> String.trim()

    if banned?(target) do
      unban(target)

      Api.create_message(
        msg.channel_id,
        embeds: [unban_success_embed(target)],
        message_reference: %{message_id: msg.id}
      )

      Logger.info("""
      unbanned #{green() <> target <> reset()}
      """)
    else
      Api.create_message(
        msg.channel_id,
        embeds: [unban_fail_embed(target)],
        message_reference: %{message_id: msg.id}
      )
    end

    :ok
  end

  @spec ban_query_success(String.t()) :: Nostrum.Struct.Embed.t()
  def ban_query_success(id) do
    %Nostrum.Struct.Embed{}
    |> put_title("yes")
    |> put_description(id <> " is banned")
  end

  @spec ban_query_fail(String.t()) :: Nostrum.Struct.Embed.t()
  def ban_query_fail(id) do
    %Nostrum.Struct.Embed{}
    |> put_title("no")
    |> put_description(id <> " is not banned")
  end

  @spec banned_command(Nostrum.Struct.Message) :: :ok
  def banned_command(msg) do
    target =
      String.split(msg.content)
      |> Enum.at(3)
      |> String.trim()

    if banned?(target) do
      Api.create_message(
        msg.channel_id,
        embeds: [ban_query_success(target)],
        message_reference: %{message_id: msg.id}
      )
    else
      Api.create_message(
        msg.channel_id,
        embeds: [ban_query_fail(target)],
        message_reference: %{message_id: msg.id}
      )
    end

    :ok
  end

  @spec get_owner_success(String.t()) :: Nostrum.Struct.Embed.t()
  def get_owner_success(owner) do
    %Nostrum.Struct.Embed{}
    |> put_title("found owner")
    |> put_description(owner)
  end

  @spec get_owner_fail() :: Nostrum.Struct.Embed.t()
  def get_owner_fail do
    %Nostrum.Struct.Embed{}
    |> put_title("did not find owner")
  end

  @spec get_owner(Nostrum.Struct.Message) :: :ok
  def get_owner(msg) do
    ref = msg.message_reference

    if ref != nil do
      owner = OwnerCache.get_owner(Integer.to_string(ref.message_id))

      if owner == nil do
        Api.create_message(
          msg.channel_id,
          embeds: [get_owner_fail()],
          message_reference: %{message_id: msg.id}
        )
      else
        Api.create_message(
          msg.channel_id,
          embeds: [get_owner_success(owner)],
          message_reference: %{message_id: msg.id}
        )
      end
    else
      Api.create_message(
        msg.channel_id,
        embeds: [get_owner_fail()],
        message_reference: %{message_id: msg.id}
      )
    end

    :ok
  end
end

defmodule PipeLine.Commands.Ban.OwnerCache do
  @moduledoc """
  GenServer module caches owner of webhook messages.
  Very similar to `PipeLine.Relay.RelayCache` 
  but I sometimes do not adhere to DRY.
  """
  use GenServer
  import IO.ANSI
  require Logger

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      {
        [],
        %{},
        Application.fetch_env!(:pipe_line, :max_owner_cache_size)
      },
      name: __MODULE__
    )
  end

  def init(state) do
    {_, _, max_size} = state

    Logger.info("""
      starting websocket message owner cache 
      pid: #{red() <> Kernel.inspect(self()) <> reset()}
      max size: #{blue() <> Integer.to_string(max_size) <> reset()}
    """)

    {:ok, state}
  end

  def handle_cast({:cache, webhook_id, owner_id}, {list, map, max_size}) do
    new_state =
      if length(list) >= max_size do
        # object to be deleted
        discard_obj =
          list
          |> Enum.reverse()
          |> List.first()

        {
          [webhook_id | list |> Enum.reverse() |> tl() |> Enum.reverse()],
          map
          |> Map.delete(discard_obj)
          |> Map.put(webhook_id, owner_id),
          max_size
        }
      else
        {
          [webhook_id | list],
          Map.put(map, webhook_id, owner_id),
          max_size
        }
      end

    Logger.debug("""
    owner cache #{red() <> Kernel.inspect(self()) <> reset()}
    new state: #{blue() <> Kernel.inspect(new_state) <> reset()}
    """)

    {:noreply, new_state}
  end

  def handle_call({:get, message_id}, _from, state) do
    {_, map, _} = state
    {:reply, Map.get(map, message_id), state}
  end

  @spec cache_owner(String.t(), String.t()) :: :ok
  def cache_owner(webhook_id, owner_id) do
    GenServer.cast(
      __MODULE__,
      {:cache, webhook_id, owner_id}
    )
  end

  @spec get_owner(String.t()) :: String.t() | nil
  def get_owner(webhook_id) do
    GenServer.call(__MODULE__, {:get, webhook_id})
  end
end
