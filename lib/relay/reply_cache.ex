defmodule PipeLine.Relay.ReplyCache do
  @moduledoc """
  Caches set number of replies.
  """
  use GenServer
  require Logger
  alias PipeLine.Relay.ReplyCache
  import IO.ANSI

  @doc """
  This struct contains a list, which stores the order 
  of message id. Map contains a hashmap that the 
  key is the message_id and the value is a list 
  of webhook message ids we want to edit later.

  Note that the first item of the list is the 
  latest message and the last item is the oldest.
  """
  defstruct list: [], map: %{}, max_size: 10

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      %ReplyCache{
        list: [],
        map: %{},
        max_size: Application.fetch_env!(:pipe_line, :max_msg_cache_size)
      },
      name: __MODULE__
    )
  end

  def init(state) do
    Logger.info("""
      starting reply cache 
      pid: #{red() <> Kernel.inspect(self()) <> reset()}
      max size: #{blue() <> Integer.to_string(state.max_size) <> reset()}
    """)

    {:ok, state}
  end

  def handle_cast({:cache, message_id, webhook_msgs}, state) do
    # if size is 10 pop it
    new_state =
      if length(state.list) >= state.max_size do
        # object to be deleted
        discard_obj =
          state.list
          |> Enum.reverse()
          |> List.first()

        %ReplyCache{
          list: [message_id | state.list |> Enum.reverse() |> tl() |> Enum.reverse()],
          map:
            state.map
            |> Map.delete(discard_obj)
            |> Map.put(message_id, webhook_msgs),
          max_size: state.max_size
        }
      else
        %ReplyCache{
          list: [message_id | state.list],
          map: Map.put(state.map, message_id, webhook_msgs),
          max_size: state.max_size
        }
      end

    Logger.info("""
    reply cache #{red() <> Kernel.inspect(self()) <> reset()}
    new state: #{blue() <> Kernel.inspect(new_state) <> reset()}
    """)

    {:noreply, new_state}
  end

  def handle_call({:get, message_id}, _from, state) do
    {:reply, Map.get(state.map, message_id), state}
  end

  @spec cache_message(String.t(), list(String.t())) :: :ok
  def cache_message(message_id, webhook_msgs) do
    GenServer.cast(__MODULE__, {:cache, message_id, webhook_msgs})
  end

  @spec get_messages(String.t()) :: list(String.t()) | nil
  def get_messages(message_id) do
    GenServer.call(__MODULE__, {:get, message_id})
  end
end
