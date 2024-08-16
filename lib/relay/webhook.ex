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

defmodule PipeLine.Relay.Webhook do
  @moduledoc """
  Clones a user with webhook.
  """

  require Logger
  alias Ecto.Repo
  alias Nostrum.Api
  alias PipeLine.Commands.Ban.OwnerCache
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

    Logger.debug("""
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
          :ets.insert(
            :webhook_cache,
            {channel_id, %{webhook_id: webhook.id, webhook_token: webhook.token}}
          )

          {:ok, webhook.id, webhook.token}

        {:error, err} ->
          {:error, err}
      end
    else
      [{_chanid, webhook_info}] = query_result
      {:ok, webhook_info.webhook_id, webhook_info.webhook_token}
    end
  end

  @spec get_avatar_url(String.t(), String.t()) :: String.t()
  def get_avatar_url(id, avatar_hash) do
    "https://cdn.discordapp.com/avatars/" <> id <> "/" <> avatar_hash
  end

  @spec relay_message(Nostrum.Struct.Message, String.t(), String.t()) ::
          {String.t(), String.t()} | nil
  def relay_message(msg, channel_id, content) do
    case get_webhook(channel_id) do
      {:ok, webhook_id, webhook_token} ->
        case Api.execute_webhook(
               webhook_id,
               webhook_token,
               %{
                 content: content,
                 username: msg.author.global_name,
                 avatar_url:
                   get_avatar_url(
                     Integer.to_string(msg.author.id),
                     msg.author.avatar
                   )
               },
               true
             ) do
          {:ok, webhook} ->
            # return the webhook id and webhook channel id
            OwnerCache.cache_owner(
              Integer.to_string(webhook.id),
              Integer.to_string(msg.author.id)
            )

            %{
              message_id: Integer.to_string(webhook.id),
              channel_id: channel_id
            }

          _ ->
            nil
        end

      {:error, _} ->
        nil
    end
  end
end
