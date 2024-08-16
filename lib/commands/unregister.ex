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

defmodule PipeLine.Commands.Unregister do
  @moduledoc """
  Unregister a channel.
  """
  require Logger
  alias Nostrum.Api
  alias PipeLine.Commands
  alias PipeLine.Database.Registration
  alias PipeLine.Database.Repo
  import IO.ANSI
  import Ecto.Query
  import Nostrum.Struct.Embed

  @spec unregisteration_failure(String.t()) :: Nostrum.Struct.Embed.t()
  def unregisteration_failure(chanid) do
    %Nostrum.Struct.Embed{}
    |> put_title("unknown error")
    |> put_description("failed to unregister <##{chanid}>, please report this incident")
  end

  @spec unregisteration_success(String.t()) :: Nostrum.Struct.Embed.t()
  def unregisteration_success(chanid) do
    %Nostrum.Struct.Embed{}
    |> put_title("success")
    |> put_description("unregistered <##{chanid}> successfully")
  end

  @spec channel_not_registered(String.t()) :: Nostrum.Struct.Embed.t()
  def channel_not_registered(chanid) do
    %Nostrum.Struct.Embed{}
    |> put_title("channel not registered")
    |> put_description("<##{chanid}> is not registered")
  end

  @spec unregister_impl(Nostrum.Struct.Message) :: :ok
  def unregister_impl(msg) do
    try do
      query =
        from r in Registration,
          where: r.channel_id == ^Integer.to_string(msg.channel_id),
          select: r.channel_id

      query_result = Repo.all(query)

      if Enum.empty?(query_result) do
        Logger.error("""
          attempt to unregister channel that isn't registered
          id: #{blue() <> Integer.to_string(msg.channel_id) <> reset()}
        """)

        Api.create_message(msg.channel_id,
          embeds: [channel_not_registered(Integer.to_string(msg.channel_id))],
          message_reference: %{message_id: msg.id}
        )
      else
        Logger.info("""
        unregistering #{blue() <> Integer.to_string(msg.channel_id) <> reset()} from db
        """)

        Repo.delete_all(query)
        :ets.delete(:chan_cache, Integer.to_string(msg.channel_id))

        Api.create_message(msg.channel_id,
          embeds: [unregisteration_success(Integer.to_string(msg.channel_id))],
          message_reference: %{message_id: msg.id}
        )
      end
    rescue
      error ->
        Api.create_message(msg.channel_id,
          embeds: [unregisteration_failure(Integer.to_string(msg.channel_id))],
          message_reference: %{message_id: msg.id}
        )

        Logger.error(Exception.format(:error, error, __STACKTRACE__))
    end

    :ok
  end

  @spec unregister(Nostrum.Struct.Message) :: :ok
  def unregister(msg) do
    if Commands.Registration.has_permission(msg.guild_id, msg.author.id) do
      unregister_impl(msg)
    else
      Commands.Registration.warn_permission(msg)
    end
  end
end
