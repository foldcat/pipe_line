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

defmodule PipeLine.Relay.RelayCache do
  @moduledoc """
  Caches set number of replies.
  """
  use GenServer
  require Logger
  alias PipeLine.Commands.BulkDelete
  alias PipeLine.Relay.RelayCache
  import IO.ANSI

  @doc """
  This struct contains a list, which stores the order 
  of message id. Map contains a hashmap that the 
  key is the message_id and the value is a list 
  of webhook message ids we want to edit later.

  Note that the first item of the list is the 
  latest message and the last item is the oldest.
  """
  @max_size Application.compile_env!(:pipe_line, :max_msg_cache_size)

  defstruct msg_order: [], webhook_ids: %{}, channel_id: %{}

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      %RelayCache{
        msg_order: [],
        webhook_ids: %{},
        channel_id: %{}
      },
      name: __MODULE__
    )
  end

  def init(state) do
    Logger.info("""
      starting reply cache 
      pid: #{red() <> Kernel.inspect(self()) <> reset()}
      max size: #{blue() <> Integer.to_string(@max_size) <> reset()}
    """)

    {:ok, state}
  end

  def handle_cast({:cache, message_id, webhook_msgs, channel_id}, state) do
    new_state =
      if length(state.msg_order) >= @max_size do
        # object to be deleted
        discard_obj =
          state.msg_order
          |> Enum.reverse()
          |> List.first()

        %RelayCache{
          msg_order: [message_id | state.msg_order |> Enum.reverse() |> tl() |> Enum.reverse()],
          webhook_ids:
            state.webhook_ids
            |> Map.delete(discard_obj)
            |> Map.put(message_id, webhook_msgs),
          channel_id:
            state.channel_id
            |> Map.delete(discard_obj)
            |> Map.put(message_id, channel_id)
        }
      else
        %RelayCache{
          msg_order: [message_id | state.msg_order],
          webhook_ids: Map.put(state.webhook_ids, message_id, webhook_msgs),
          channel_id: Map.put(state.channel_id, message_id, channel_id)
        }
      end

    Logger.debug("""
    reply cache #{red() <> Kernel.inspect(self()) <> reset()}
    new state: #{blue() <> Kernel.inspect(new_state) <> reset()}
    """)

    {:noreply, new_state}
  end

  def handle_cast({:bulk_delete, amount}, state) do
    BulkDelete.bulk_delete(amount, state)

    delete_targets =
      state.msg_order
      |> Enum.take(amount)

    new_webhook_ids = Map.drop(state.webhook_ids, [delete_targets])
    new_channel_id = Map.drop(state.channel_id, [delete_targets])
    new_msg_order = Enum.drop(state.msg_order, amount)

    {:noreply,
     %RelayCache{
       msg_order: new_msg_order,
       webhook_ids: new_webhook_ids,
       channel_id: new_channel_id
     }}
  end

  def handle_call({:get, message_id}, _from, state) do
    {:reply, Map.get(state.webhook_ids, message_id), state}
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @spec cache_message(Nostrum.Struct.Message, list(String.t())) :: :ok
  def cache_message(msg, webhook_msgs) do
    GenServer.cast(
      __MODULE__,
      {
        :cache,
        Integer.to_string(msg.id),
        webhook_msgs,
        Integer.to_string(msg.channel_id)
      }
    )
  end

  @spec get_messages(String.t()) :: {list(String.t()), String.t()} | nil
  def get_messages(message_id) do
    GenServer.call(__MODULE__, {:get, message_id})
  end

  @spec get_state() :: RelayCache
  def get_state do
    GenServer.call(__MODULE__, {:get_state})
  end

  @spec bulk_delete(integer) :: :ok
  def bulk_delete(amount) do
    GenServer.cast(__MODULE__, {:bulk_delete, amount})
  end
end
