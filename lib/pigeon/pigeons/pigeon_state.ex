defmodule Pigeon.Pigeons.PigeonState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pigeons" do
    field(:chat, :string)
    field(:hunger, :integer)
    field(:owners, {:array, :string})
    field(:status, :string)
    field(:personality, :string)
    field(:requested_by, :string)
    timestamps()
  end

  def changeset(pigeon, attrs) do
    pigeon
    |> cast(attrs, [:chat, :hunger])
    |> validate_required([:chat, :hunger])
  end
end
