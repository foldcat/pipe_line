defmodule PipeLine.Relay.Censor do
  @moduledoc """
  Censors bad words.
  """
  use GenServer
  require Logger
  import IO.ANSI

  def start_link(_state) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_state) do
    blacklist = Application.fetch_env!(:pipe_line, :blacklist)
    {:ok, Expletive.configure(blacklist: blacklist)}
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
    "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ "
  end

  @spec emoji?(String.t()) :: boolean
  def emoji?(str) do
    String.match?(str, ~r/\p{So}/u)
  end

  @spec replace_unicode(String.t()) :: String.t()
  def replace_unicode(str) do
    Logger.info("sanitizing #{green() <> str <> reset()}")

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
