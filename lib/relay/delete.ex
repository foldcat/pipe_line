defmodule PipeLine.Relay.Delete do
  @moduledoc """
  Handles delection of messages.
  """

  require Logger
  import IO.ANSI
  alias Nostrum.Api
  alias PipeLine.Relay.RelayCache

  @spec delete_impl(String.t()) :: :ok
  def delete_impl(id) do
    targets = RelayCache.get_messages(id)

    if not (targets == nil) do
      Enum.each(
        targets,
        fn ws_msg ->
          Api.delete_message(
            String.to_integer(ws_msg.channel_id),
            String.to_integer(ws_msg.message_id)
          )
        end
      )

      Logger.info("""
      deleted message of id #{red() <> id <> reset()}
      """)
    end
  end

  @spec delete(String.t(), String.t()) :: :ok
  def delete(id, channel_id) do
    if not Enum.empty?(
         :ets.lookup(
           :chan_cache,
           channel_id
         )
       ) do
      case(Hammer.check_rate("delete-msg#{id}", 10_000, 1)) do
        {:allow, _count} ->
          delete_impl(id)

        {:deny, _limit} ->
          Logger.info("""
          not deleting #{red() <> id <> red()}
          as limit is exceeded
          """)
      end

      :ok
    end
  end
end

defmodule PipeLine.Relay.Delete.Lock do
  @moduledoc """
  With lock engaged delete will become 
  noop functions.
  """
  use GenServer

  def start_link(_) do
    # false: disengaged
    GenServer.start_link(__MODULE__, false, name: __MODULE__)
  end

  def init(state), do: {:ok, state}

  def handle_cast(:engage, _) do
    {:noreply, true}
  end

  def handle_cast(:disengage, _) do
    {:noreply, false}
  end

  def handle_call(:engaged?, _from, state) do
    {:reply, state, state}
  end

  def engage, do: GenServer.cast(__MODULE__, :engage)
  def disengage, do: GenServer.cast(__MODULE__, :disengage)

  @spec engaged?() :: boolean
  def engaged?, do: GenServer.call(__MODULE__, :engaged?)
end
