# lib/pigeon/accounts.ex
defmodule Pigeon.Accounts do
  alias Pigeon.Repo
  alias Pigeon.Accounts.User

  def register(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(username, password) do
    user = Repo.get_by(User, username: username)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) -> {:ok, user}
      user -> {:error, :bad_password}
      true -> Bcrypt.no_user_verify(); {:error, :not_found}
    end
  end
end
