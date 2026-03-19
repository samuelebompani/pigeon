# lib/pigeon_web/auth.ex
defmodule PigeonWeb.Auth do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:require_authenticated, _params, session, socket) do
    case session do
      %{"username" => username} ->
        {:cont, assign(socket, :me, username)}
      _ ->
        {:halt, redirect(socket, to: "/login")}
    end
  end
end
