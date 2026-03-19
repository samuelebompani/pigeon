# lib/pigeon_web/live/register_live.ex
defmodule PigeonWeb.RegisterLive do
  use PigeonWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-100">
      <div class="bg-white p-8 rounded shadow w-80 space-y-4">
        <h1 class="text-2xl font-bold text-center">🐦 Create account</h1>

        <form action="/register" method="post" class="space-y-3">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input name="username" placeholder="Username"
            class="w-full border rounded px-3 py-2" />
          <input name="password" type="password" placeholder="Password"
            class="w-full border rounded px-3 py-2" />
          <button class="w-full bg-purple-600 text-white py-2 rounded">
            Register
          </button>
        </form>

        <p class="text-sm text-center">
          Have an account? <a href="/login" class="underline text-purple-600">Log in</a>
        </p>
      </div>
    </div>
    """
  end
end
