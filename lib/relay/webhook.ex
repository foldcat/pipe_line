defmodule PipeLine.Relay.Webhook do
  @moduledoc """
  Clones a user with webhook.
  """

  @doc """
  Create a webhook in a channel and stores it 
  inside a database, and caches it with ets.
  If the above succeed, returns :ok
  Return :done if the channel is already
  registered.
  """
  @spec create_webhook(integer) :: :ok | :done
  def create_webhook(channel_id) do
    :ok
  end
end
