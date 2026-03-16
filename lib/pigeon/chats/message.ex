defmodule Pigeon.Chats.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :chat, :string
    field :username, :string
    field :content, :string

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:chat, :username, :content])
    |> validate_required([:chat, :username, :content])
  end
end
