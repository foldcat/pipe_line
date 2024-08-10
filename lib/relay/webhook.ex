defmodule PipeLine.Relay.Webhook do
  @moduledoc """
  Clones a user with webhook.
  """

  require Logger
  alias Ecto.Repo
  alias Nostrum.Api
  alias PipeLine.Database.Repo
  alias PipeLine.Database.Webhooks
  import IO.ANSI

  @doc """
  Create a webhook in a channel and stores it 
  inside a database, and caches it with ets.
  Returns the webhook url. Will return the 
  webhook url stored in the dbif the channel 
  already has a webhook.
  """

  @spec get_webhook(integer) :: {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def get_webhook(channel_id) do
    query_result = :ets.lookup(:webhook_cache, channel_id)

    Logger.info("""
      querying webhook of channel id #{blue() <> channel_id <> reset()}
      result: #{blue() <> Kernel.inspect(query_result) <> reset()}
    """)

    if Enum.empty?(query_result) do
      {:ok, webhook} =
        Api.create_webhook(
          channel_id,
          %{name: "pipeline relay", avatar: ""}
        )

      Logger.info("""
      created webhook 
      #{blue() <> Kernel.inspect(webhook) <> reset()}
      """)

      # TODO: rework to store token
      case Repo.insert(%Webhooks{
             channel_id: channel_id,
             webhook_id: webhook.id,
             webhook_token: webhook.token
           }) do
        {:ok, _} ->
          :ets.insert(:webhook_cache, {channel_id, webhook.id, webhook.token})
          {:ok, webhook.id}

        {:error, err} ->
          {:error, err}
      end
    else
      [{_chanid, webhook_id, _webhook_token}] = query_result
      {:ok, webhook_id}
    end
  end
end
