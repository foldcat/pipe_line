defmodule PipeLine.Relay.ReplyCache do
  @moduledoc """
  Caches set number of replies.
  """
  use GenServer
  require Logger
  alias PipeLine.Commands.BulkDelete
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
  defstruct msg_order: [], webhook_ids: %{}, channel_id: %{}, max_size: 10

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      %ReplyCache{
        msg_order: [],
        webhook_ids: %{},
        channel_id: %{},
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

  def handle_cast({:cache, message_id, webhook_msgs, channel_id}, state) do
    new_state =
      if length(state.msg_order) >= state.max_size do
        # object to be deleted
        discard_obj =
          state.msg_order
          |> Enum.reverse()
          |> List.first()

        %ReplyCache{
          msg_order: [message_id | state.msg_order |> Enum.reverse() |> tl() |> Enum.reverse()],
          webhook_ids:
            state.webhook_ids
            |> Map.delete(discard_obj)
            |> Map.put(message_id, webhook_msgs),
          channel_id:
            state.channel_id
            |> Map.delete(discard_obj)
            |> Map.put(message_id, channel_id),
          max_size: state.max_size
        }
      else
        %ReplyCache{
          msg_order: [message_id | state.msg_order],
          webhook_ids: Map.put(state.webhook_ids, message_id, webhook_msgs),
          channel_id: Map.put(state.channel_id, message_id, channel_id),
          max_size: state.max_size
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
     %ReplyCache{
       msg_order: new_msg_order,
       webhook_ids: new_webhook_ids,
       channel_id: new_channel_id,
       max_size: state.max_size
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

  @spec get_state() :: ReplyCache
  def get_state do
    GenServer.call(__MODULE__, {:get_state})
  end

  @spec bulk_delete(integer) :: :ok
  def bulk_delete(amount) do
    GenServer.cast(__MODULE__, {:bulk_delete, amount})
  end
end
