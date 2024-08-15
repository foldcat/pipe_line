defmodule PipeLine.Commands.Admin do
  @moduledoc """
  Stores and distinguish between admins and 
  normal users.
  """
  require Logger
  import IO.ANSI
  alias Nostrum.Api
  alias PipeLine.Database.Admin
  alias PipeLine.Database.Repo
  import Ecto.Query
  import Nostrum.Struct.Embed

  @spec insert_admin(String.t()) :: :ok
  def insert_admin(id) do
    :ets.insert(:admin, {id})

    Repo.insert(%Admin{
      user_id: id
    })

    :ok
  end

  @spec delete_admin(String.t()) :: :ok
  def delete_admin(id) do
    query =
      from a in Admin,
        where: a.user_id == ^id,
        select: a.user_id

    :ets.delete(:admin, id)

    Repo.delete_all(query)

    :ok
  end

  @spec delete_admin_iex(String.t()) :: :ok
  def delete_admin_iex(author_id) do
    delete_admin(author_id)

    Logger.info("""
    #{blue() <> author_id <> reset()}'s admin rights have been revoked
    """)

    :ok
  end

  @doc """
  `register_admin` but run in iex.
  """
  @spec register_admin_iex(String.t()) :: :ok
  def register_admin_iex(author_id) do
    insert_admin(author_id)

    Logger.info("""
    registered #{blue() <> author_id <> reset()} as an administrator
    """)

    :ok
  end

  @spec register_admin(Nostrum.Struct.Message) :: :ok
  def register_admin(msg) do
    author_id = Integer.to_string(msg.author.id)

    insert_admin(author_id)

    Logger.info("""
    registered #{blue() <> msg.author.global_name <> reset()} as an administrator
    their id is #{blue() <> author_id <> reset()}
    """)

    :ok
  end

  @spec admin?(String.t()) :: boolean
  def admin?(id) do
    not Enum.empty?(:ets.lookup(:admin, id))
  end

  @spec admin_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def admin_embed(username) do
    %Nostrum.Struct.Embed{}
    |> put_title("yes")
    |> put_description(username <> " is admin")
  end

  @spec not_admin_embed(String.t()) :: Nostrum.Struct.Embed.t()
  def not_admin_embed(username) do
    %Nostrum.Struct.Embed{}
    |> put_title("no")
    |> put_description(username <> " is not admin")
  end

  @spec am_i_admin?(Nostrum.Struct.Message) :: :ok
  def am_i_admin?(msg) do
    author = Integer.to_string(msg.author.id)

    if admin?(author) do
      Api.create_message(
        msg.channel_id,
        embeds: [admin_embed(msg.author.global_name)],
        message_reference: %{message_id: msg.id}
      )
    else
      Api.create_message(
        msg.channel_id,
        embeds: [not_admin_embed(msg.author.global_name)],
        message_reference: %{message_id: msg.id}
      )
    end

    :ok
  end

  @spec no_permission_embed() :: Nostrum.Struct.Embed.t()
  def no_permission_embed do
    %Nostrum.Struct.Embed{}
    |> put_title("forbidden")
    |> put_description("you have no permission")
  end

  @doc """
  Wrapper around a lambda that will complain if 
  user has no permission.
  """
  def permcheck(msg, lambda) do
    if admin?(Integer.to_string(msg.author.id)) do
      lambda.()
    else
      Api.create_message(
        msg.channel_id,
        embeds: [no_permission_embed()],
        message_reference: %{message_id: msg.id}
      )
    end
  end
end
