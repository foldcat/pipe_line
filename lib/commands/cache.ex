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

defmodule PipeLine.Commands.Cache do
  @moduledoc """
  module that checks if individual 
  channel is cached
  """
  alias Nostrum.Api
  import Nostrum.Struct.Embed

  @spec cached_embed() :: Nostrum.Struct.Embed.t()
  def cached_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("ets query")
    |> put_description("this channel is cached")
  end

  @spec not_cached_embed() :: Nostrum.Struct.Embed.t()
  def not_cached_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("ets query")
    |> put_description("this channel is not cached")
  end

  @spec cached?(Nostrum.Struct.Message) :: :ok
  def cached?(msg) do
    query_result =
      :ets.lookup(
        :chan_cache,
        Integer.to_string(msg.channel_id)
      )

    if Enum.empty?(query_result) do
      Api.create_message(msg.channel_id,
        embeds: [not_cached_embed()],
        message_reference: %{message_id: msg.id}
      )
    else
      Api.create_message(msg.channel_id,
        embeds: [cached_embed()],
        message_reference: %{message_id: msg.id}
      )
    end

    :ok
  end
end
