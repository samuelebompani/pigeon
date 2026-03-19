defmodule PigeonWeb.SessionController do
  use PigeonWeb, :controller
  alias Pigeon.Accounts

  def create(conn, %{"username" => u, "password" => p}) do
    case Accounts.authenticate(u, p) do
      {:ok, user} ->
        conn
        |> put_session(:username, user.username)
        |> redirect(to: "/")
      _ ->
        conn
        |> put_flash(:error, "Invalid credentials")
        |> redirect(to: "/login")
    end
  end

  def delete(conn, _) do
    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
