# lib/pigeon_web/live/login_live.ex
defmodule PigeonWeb.LoginLive do
  use PigeonWeb, :live_view
  alias Pigeon.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"username" => "", "password" => ""}), error: nil)}
  end

  def handle_event("login", %{"username" => u, "password" => p}, socket) do
    case Accounts.authenticate(u, p) do
      {:ok, user} ->
        {:noreply, redirect(socket, to: "/") |> put_session(:username, user.username)}

      _ ->
        {:noreply, assign(socket, error: "Invalid username or password")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-100">
      <div class="bg-white p-8 rounded shadow w-80 space-y-4">
        <h1 class="text-2xl font-bold text-center">🐦 Pigeon</h1>

        <%= if @error do %>
          <p class="text-red-500 text-sm">{@error}</p>
        <% end %>

        <form phx-submit="login" class="space-y-3">
          <input
            name="username"
            placeholder="Username"
            class="w-full border rounded px-3 py-2"
            autocomplete="username"
          />
          <input
            name="password"
            type="password"
            placeholder="Password"
            class="w-full border rounded px-3 py-2"
            autocomplete="current-password"
          />
          <button class="w-full bg-purple-600 text-white py-2 rounded">
            Log in
          </button>
        </form>

        <p class="text-sm text-center">
          No account? <a href="/register" class="underline text-purple-600">Register</a>
        </p>
      </div>
    </div>
    """
  end

  defp put_session(socket, key, value) do
    push_event(socket, "put_session", %{key: key, value: value})
  end
end
