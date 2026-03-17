defmodule Pigeon.Pigeons.PigeonState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pigeons" do
    field(:chat, :string)
    field(:hunger, :integer)

    # ["User_123", "User_456"]
    field(:owners, {:array, :string})
    # "pending" | "active"
    field(:status, :string)
    timestamps()
  end

  def changeset(pigeon, attrs) do
    pigeon
    |> cast(attrs, [:chat, :hunger])
    |> validate_required([:chat, :hunger])
  end
end
