# lib/pigeon_web/live/home_live.ex
defmodule PigeonWeb.HomeLive do
  use PigeonWeb, :live_view

  alias Pigeon.Repo
  alias Pigeon.Accounts.User

  def mount(_params, _session, socket) do
    me = socket.assigns.me

    users =
      Repo.all(User)
      |> Enum.map(& &1.username)
      |> Enum.reject(&(&1 == me))

    {:ok, assign(socket, :users, users)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 p-10">
      <div class="max-w-sm mx-auto bg-white rounded shadow p-6 space-y-4">
        <div class="flex justify-between items-center">
          <h1 class="text-xl text-black font-bold">🐦 Pigeon</h1>
          <form action="/logout" method="post">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <input type="hidden" name="_method" value="delete" />
            <button class="text-sm text-gray-500 underline">Log out</button>
          </form>
        </div>

        <p class="text-gray-600 text-sm">Logged in as <b>{@me}</b></p>

        <div class="space-y-2">
          <p class="font-semibold text-sm text-gray-700">Chat with:</p>
          <%= for user <- @users do %>
            <a href={"/chat/#{user}"}
               class="block px-4 py-2 rounded bg-purple-50 hover:bg-purple-100 text-purple-800">
              @{user}
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
