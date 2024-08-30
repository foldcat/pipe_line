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

defmodule PipeLine.Relay.Censor do
  @moduledoc """
  Censors bad words.
  """
  use GenServer
  require Logger
  import IO.ANSI

  @blacklist Application.compile_env!(:pipe_line, :blacklist)

  def start_link(_state) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_state) do
    Logger.info("""
      starting censorship
      pid: #{red() <> Kernel.inspect(self()) <> reset()}
    """)

    {:ok, Expletive.configure(blacklist: @blacklist)}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @spec sanitize(String.t()) :: String.t()
  def sanitize(value) do
    blacklist = GenServer.call(__MODULE__, :get)
    Expletive.sanitize(value, blacklist)
  end

  @spec allowed_chars() :: String.t()
  def allowed_chars do
    "\n!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ "
  end

  @spec emoji?(String.t()) :: boolean
  def emoji?(str) do
    String.match?(str, ~r/\p{So}/u)
  end

  @spec replace_unicode(String.t()) :: String.t()
  def replace_unicode(str) do
    Logger.debug("sanitizing #{green() <> str <> reset()}")

    str
    |> String.codepoints()
    |> Enum.map_join("", fn codepoint ->
      cond do
        emoji?(codepoint) ->
          codepoint

        String.contains?(allowed_chars(), codepoint) ->
          codepoint

        true ->
          "₏"
      end
    end)
  end
end
