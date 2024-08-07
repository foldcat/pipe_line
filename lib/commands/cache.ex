defmodule PipeLine.Cache do
  @moduledoc """
  module that checks if individual 
  channel is cached
  """
  use Nostrum.Consumer
  alias Nostrum.Api
  import Nostrum.Struct.Embed

  @spec cached_embed() :: Nostrum.Struct.Embed.t()
  def cached_embed() do
    %Nostrum.Struct.Embed{}
    |> put_title("ets query")
    |> put_description("this channel is cached")
  end

  @spec not_cached_embed() :: Nostrum.Struct.Embed.t()
  def not_cached_embed() do
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
      Api.create_message(msg.channel_id, embeds: [not_cached_embed()])
    else
      Api.create_message(msg.channel_id, embeds: [cached_embed()])
    end

    :ok
  end
end
