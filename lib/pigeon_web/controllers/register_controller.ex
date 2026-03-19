defmodule PigeonWeb.RegisterController do
  use PigeonWeb, :controller
  alias Pigeon.Accounts

  def create(conn, %{"username" => u, "password" => p}) do
    case Accounts.register(%{username: u, password: p}) do
      {:ok, user} ->
        conn
        |> put_session(:username, user.username)
        |> redirect(to: "/")
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn
        |> put_flash(:error, inspect(errors))
        |> redirect(to: "/register")
    end
  end
end
