defmodule PipeLine.Commands.Ban do
  @moduledoc """
  Ban an user.
  """

  require Logger
  alias Nostrum.Api
  alias PipeLine.Commands.Ban.OwnerCache

  @doc """
  Reply to target's message to ban them.
  Manually inputting their user id also works.
  In Discord one can specify the ban time, 
  when left blank defaults to preminent
  """

  @spec ban(Nostrum.Struct.Message) :: :ok
  def ban(msg) do
    input = String.split(msg.content)

    Logger.info(Kernel.inspect(input))

    cond do
      # admin simply replied to some message without
      # specifying who or duration
      # permaban the one in the reply
      length(input) == 2 ->
        ref = msg.message_reference
        Logger.info(Kernel.inspect(msg))

        if ref != nil do
          Logger.info(Kernel.inspect(ref))
          owner = OwnerCache.get_owner(Integer.to_string(ref.message_id))
          Logger.info(Kernel.inspect(owner))

          if owner != nil do
            Logger.info("got owner")
            Logger.info(Kernel.inspect(owner))
          else
            Logger.info("did not owner")
            {:ok, target_msg} = Api.get_channel_message(ref.channel_id, ref.message_id)
            Logger.info(Kernel.inspect(target_msg.author.id))
          end
        end
    end

    :ok
  end
end

defmodule PipeLine.Commands.Ban.OwnerCache do
  @moduledoc """
  GenServer module caches owner of webhook messages.
  Very similar to `PipeLine.Relay.ReplyCache` 
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
        Application.fetch_env!(:pipe_line, :max_ban_hook_cache_size)
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
