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

  @spec get_webhook(String.t()) :: {:ok, String.t(), String.t()} | {:error, Ecto.Changeset.t()}
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

      case Repo.insert(%Webhooks{
             channel_id: channel_id,
             webhook_id: webhook.id,
             webhook_token: webhook.token
           }) do
        {:ok, _} ->
          :ets.insert(:webhook_cache, {channel_id, webhook.id, webhook.token})
          {:ok, webhook.id, webhook.token}

        {:error, err} ->
          {:error, err}
      end
    else
      [{_chanid, webhook_id, webhook_token}] = query_result
      {:ok, webhook_id, webhook_token}
    end
  end

  @spec get_avatar_url(String.t(), String.t()) :: String.t()
  def get_avatar_url(id, avatar_hash) do
    "https://cdn.discordapp.com/avatars/" <> id <> "/" <> avatar_hash
  end

  @spec relay_message(Nostrum.Struct.Message, String.t()) :: :ok
  def relay_message(msg, channel_id) do
    case get_webhook(channel_id) do
      {:ok, webhook_id, webhook_token} ->
        Logger.info(Kernel.inspect(msg))

        Api.execute_webhook(
          webhook_id,
          webhook_token,
          %{
            content: msg.content,
            username: msg.author.global_name,
            avatar_url: get_avatar_url(Integer.to_string(msg.author.id), msg.author.avatar)
          }
        )

      {:error, _} ->
        :noop
    end

    :ok
  end
end
