defmodule Pigeon.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
    |> validate_length(:username, min: 2, max: 20)
    |> validate_length(:password, min: 4)
    |> unique_constraint(:username)
    |> hash_password()
  end

  defp hash_password(%{valid?: true, changes: %{password: pw}} = cs) do
    change(cs, password_hash: Bcrypt.hash_pwd_salt(pw))
  end
  defp hash_password(cs), do: cs
end
