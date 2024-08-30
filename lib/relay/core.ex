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

defmodule PipeLine.Relay.Core do
  @moduledoc """
  Process that handles relaying messages 
  to multiple Discord channels.
  """
  alias Nostrum.Api
  alias PipeLine.Commands.Ban
  alias PipeLine.Relay.Censor
  alias PipeLine.Relay.RelayCache
  alias PipeLine.Relay.Tracker
  alias PipeLine.Relay.Webhook
  require Logger
  import IO.ANSI
  import Nostrum.Struct.Embed

  @allowed_bots Application.compile_env!(:pipe_line, :allowed_bots)

  @spec relay_ratelimit_exceeded() :: Nostrum.Struct.Embed.t()
  def relay_ratelimit_exceeded do
    %Nostrum.Struct.Embed{}
    |> put_title("rate limit exceeded")
    |> put_description("you have exceeded the 2 messages per 5 seconds rate limit")
  end

  @spec warn_relay_limit_exceeded(Nostrum.Struct.Message, String.t()) :: :ok
  def warn_relay_limit_exceeded(msg, author_id) do
    Logger.info("""
    not relaying #{red() <> Integer.to_string(msg.id) <> red()}
    as limit is exceeded
    """)

    case(Hammer.check_rate("relay-msg-warn#{author_id}", 5000, 1)) do
      {:allow, _count} ->
        Api.create_message(
          msg.channel_id,
          embeds: [relay_ratelimit_exceeded()],
          message_reference: %{message_id: msg.id}
        )

      {:deny, _limit} ->
        nil
    end

    :ok
  end

  @spec truncate(String.t()) :: String.t()
  def truncate(content) do
    if String.length(content) > 10 do
      fmt =
        String.slice(content, 0..10)
        |> String.replace("\n", " ")

      "#{fmt}..."
    else
      content
    end
  end

  @doc """
  Formats a reply. 
  Returns empty string if there are none.
  """
  @spec format_reply(Nostrum.Struct.Message) :: String.t()
  def format_reply(msg) do
    ref = msg.referenced_message

    if ref == nil do
      ""
    else
      author = ref.author.global_name
      username = ref.author.username

      cond do
        author != nil ->
          "-# replying to #{author} :: #{truncate(ref.content)} \n"

        username != nil ->
          "-# replying to #{username} :: #{truncate(ref.content)} \n"

        true ->
          "-# replying to [unknown user] :: #{truncate(ref.content)} \n"
      end
    end
  end

  @doc """
  `pipe_single_msg` takes a message object and sends it 
  to every channel that is registered BUT the channel 
  id supplied to from_channel argument.
  """
  @spec pipe_msg(Nostrum.Struct.Message, String.t()) :: :ok
  def pipe_msg(msg, from_channel) do
    cache_lookup = :ets.tab2list(:chan_cache)

    reply_format = format_reply(msg)

    _ = Tracker.update_channel("#{from_channel}", 1)
    Logger.debug("cache result: #{inspect(cache_lookup |> Enum.map(fn {item} -> item end))}")

    Logger.debug(
      "flat? #{inspect(cache_lookup |> Enum.map(fn {item} -> item end) |> Tracker.get_merged_channel_list())}"
    )

    Logger.debug(
      "merged channel list: #{inspect(cache_lookup |> Tracker.get_merged_channel_list())}"
    )

    webhook_ids =
      cache_lookup
      |> Enum.map(fn {item} -> item end)
      |> Tracker.get_merged_channel_list()
      |> Enum.map(fn chanid ->
        # do not relay message back to the original channel
        if chanid == from_channel do
          nil
        else
          Logger.debug("""
            relaying message #{blue() <> Integer.to_string(msg.id) <> reset()}
            to channel #{blue() <> chanid <> reset()} 
            from channel #{blue() <> from_channel <> reset()}
          """)

          santized_content =
            msg.content
            |> Censor.replace_unicode()
            |> Censor.sanitize()

          Webhook.relay_message(msg, chanid, reply_format <> santized_content)
        end
      end)
      |> Enum.filter(fn item -> item != nil end)

    RelayCache.cache_message(msg, webhook_ids)

    :ok
  end

  @spec relay_all(Nostrum.Struct.Message, list({String.t()})) :: :ok
  def relay_all(msg, cache_lookup) do
    # said message is inside registered channel list
    if not Enum.empty?(cache_lookup) do
      pipe_msg(msg, Integer.to_string(msg.channel_id))

      Logger.info("""
        relayed #{blue() <> msg.author.global_name <> reset()}'s (#{green() <> Integer.to_string(msg.author.id) <> reset()}) message:
      #{green() <> msg.content <> reset()}
      """)
    end

    :ok
  end

  @spec relay_msg(Nostrum.Struct.Message) :: :ok
  def relay_msg(msg) do
    author_id = Integer.to_string(msg.author.id)

    cond do
      msg.author.bot == nil and not Ban.banned?(author_id) ->
        case(Hammer.check_rate("relay-msg#{author_id}", 5000, 2)) do
          {:allow, _count} ->
            cache_lookup =
              :ets.lookup(
                :chan_cache,
                Integer.to_string(msg.channel_id)
              )

            # said message is inside registered channel list
            relay_all(msg, cache_lookup)

          {:deny, _limit} ->
            warn_relay_limit_exceeded(msg, author_id)
        end

      Integer.to_string(msg.author.id) in @allowed_bots ->
        cache_lookup =
          :ets.lookup(
            :chan_cache,
            Integer.to_string(msg.channel_id)
          )

        relay_all(msg, cache_lookup)

      true ->
        :noop
    end

    :ok
  end
end
