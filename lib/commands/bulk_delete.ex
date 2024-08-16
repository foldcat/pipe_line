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

defmodule PipeLine.Commands.BulkDelete do
  @moduledoc """
  Bulk deletes messages.
  """

  require Logger
  alias Nostrum.Api
  alias PipeLine.Relay.Delete.Lock
  alias PipeLine.Relay.RelayCache

  # what even is this

  # im keeping this here to shame myself

  # base case when theres one item in keys
  # return it whole
  # def _merge_data([key], map1, map2, accum) do
  #   target1 = Map.get(map1, key)
  #   target2 = Map.get(map2, key)
  #
  #   result =
  #     cond do
  #       target1 == nil ->
  #         [{key, target1}]
  #
  #       target2 == nil ->
  #         [{key, target2}]
  #
  #       true ->
  #         [{key, target1 ++ target2}]
  #     end
  #
  #   accum ++ result
  # end
  #
  # def _merge_data([key | new_key], map1, map2, accum) do
  #   target1 = Map.get(map1, key)
  #   target2 = Map.get(map2, key)
  #
  #   new_accum =
  #     cond do
  #       target1 == nil ->
  #         [{key, target1}]
  #
  #       target2 == nil ->
  #         [{key, target2}]
  #
  #       true ->
  #         [{key, target1 ++ target2}]
  #     end
  #
  #   _merge_data(new_key, map1, map2, accum ++ new_accum)
  # end
  #
  # @doc """
  # Merge two maps that values are lists
  # """
  # def merge_data(map1, map2) do
  #   keys =
  #     (Map.keys(map1) ++ Map.keys(map2))
  #     |> Enum.into(MapSet.new())
  #     |> Enum.to_list()
  #
  #   _merge_data(keys, map1, map2, [])
  #   |> Enum.into(%{})
  # end

  def pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await/1)
  end

  @spec bulk_delete(integer, RelayCache) :: :ok
  def bulk_delete(amount, state) do
    Lock.engage()

    try do
      # to be deleted
      target_webhook_messages =
        state.msg_order
        |> Enum.take(amount)
        |> Enum.map(fn msg_id ->
          Map.get(state.webhook_ids, msg_id)
        end)
        |> List.flatten()
        |> Enum.group_by(fn data -> data.channel_id end)

      target_source_messages =
        state.msg_order
        |> Enum.take(amount)
        |> Enum.map(fn msg_id ->
          %{channel_id: Map.get(state.channel_id, msg_id), message_id: msg_id}
        end)
        |> Enum.group_by(fn data -> data.channel_id end)

      targets =
        Map.merge(
          target_webhook_messages,
          target_source_messages,
          fn _k, va, vb -> va ++ vb end
        )

      formatted_target =
        for {k, values} <- targets, into: %{} do
          {k, Enum.map(values, fn data -> data.message_id end)}
        end

      pmap(
        formatted_target,
        fn {k, v} ->
          Api.bulk_delete_messages!(k, v)
        end
      )
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
    end

    Lock.disengage()
  end

  @spec bulk_delete_cmd(Nostrum.Struct.Message) :: :ok
  def bulk_delete_cmd(msg) do
    ">! purge" <> amount_ = msg.content

    amount =
      amount_
      |> String.trim()
      |> String.to_integer()

    RelayCache.bulk_delete(amount)

    :ok
  end
end
