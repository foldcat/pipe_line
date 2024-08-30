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

defmodule PipeLine.Relay.Tracker do
  @moduledoc """
  Tracks activity of various channels on a rolling basis
  """
  use GenServer
  require Logger
  alias PipeLine.Relay.Tracker
  import IO.ANSI

  # in milliseconds
  @activity_decay Application.compile_env(:pipe_line, :activity_decay_ms)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Logger.info("""
      started activity tracker
      pid: #{red() <> Kernel.inspect(self()) <> reset()}
      activity lifespan: #{blue() <> "#{Float.to_string(@activity_decay / 1000.0)} seconds" <> reset()}
    """)

    {:ok, state}
  end

  def process_activities(map) do
    map
    |> Enum.to_list()
    |> Enum.map(fn {k, v} -> {v, k} end)
    |> Enum.into(Heap.max())
    |> Enum.map(fn {_v, k} -> k end)
  end

  def handle_call({:get_map}, _from, map), do: {:reply, map, map}

  def handle_call({:get_merged_list, channels}, _from, map) do
    processed =
      map
      |> Tracker.process_activities()
      |> Enum.concat(channels)
      |> Enum.uniq()

    {:reply, processed, map}
  end

  def handle_call({:get_list}, _from, map) do
    processed = map |> Tracker.process_activities()
    {:reply, processed, map}
  end

  def do_update(channel_id, delta, map) do
    result =
      map
      |> Map.put(channel_id, (map[channel_id] || 0) + delta)

    if result[channel_id] >= 0 do
      result =
        if result[channel_id] == 0,
          do: result |> Map.delete(channel_id),
          else: result

      {:noreply, result}
    else
      {:error, "Channels cannot have negative activity!"}
    end
  end

  def handle_info({:rescind_update, channel_id, delta}, map) do
    response = do_update(channel_id, -delta, map)
    Logger.debug("untracked activity on channel #{channel_id}")
    response
  end

  def handle_cast({:update, channel_id, delta}, map) do
    response = do_update(channel_id, delta, map)
    Process.send_after(self(), {:rescind_update, channel_id, delta}, @activity_decay)
    Logger.debug("tracked activity on channel #{channel_id}")
    response
  end

  def get_channel_activities, do: GenServer.call(__MODULE__, {:get_map})

  def get_channel_list, do: GenServer.call(__MODULE__, {:get_list})

  @spec get_merged_channel_list(channels :: list(String.t())) :: list(String.t())
  def get_merged_channel_list(channels),
    do: GenServer.call(__MODULE__, {:get_merged_list, channels})

  @spec update_channel(channel_id :: String.t(), delta :: Integer) :: :ok
  def update_channel(channel_id, delta) do
    GenServer.cast(__MODULE__, {:update, channel_id, delta})
    :ok
  end
end
