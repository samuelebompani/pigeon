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
    <style>
      @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500&display=swap');
      .pigeon-app { font-family: 'DM Sans', sans-serif; }
      .auth-input:focus { outline: none; border-color: rgba(180,160,240,0.4) !important; }
      .auth-input::placeholder { color: #3a3840; }
      .auth-btn:hover { background: #4d3f8a !important; }
    </style>

    <div
      class="pigeon-app"
      style="background:#0f0f11;color:#e8e6df;min-height:100dvh;display:flex;align-items:center;justify-content:center;padding:20px;"
    >
      <div style="width:100%;max-width:320px;">
        <div style="margin-bottom:32px;">
          <div style="font-size:24px;font-weight:500;color:#eeeae0;letter-spacing:-0.02em;margin-bottom:6px;">
            🕊️ Pigeon
          </div>
          <div style="font-size:13px;color:#4a4840;">Sign in to continue</div>
        </div>

        <%= if @error do %>
          <div style="background:rgba(220,100,100,0.1);border:1px solid rgba(220,100,100,0.2);border-radius:8px;padding:10px 12px;font-size:13px;color:#d08080;margin-bottom:16px;">
            {@error}
          </div>
        <% end %>

        <form action="/login" method="post" style="display:flex;flex-direction:column;gap:10px;">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input
            name="username"
            placeholder="Username"
            autocomplete="username"
            class="auth-input"
            style="font-family:'DM Sans',sans-serif;font-size:14px;background:#1c1b24;border:1px solid rgba(255,255,255,0.1);color:#e0dcf0;border-radius:10px;padding:11px 14px;transition:border-color 0.15s;"
          />
          <input
            name="password"
            type="password"
            placeholder="Password"
            autocomplete="current-password"
            class="auth-input"
            style="font-family:'DM Sans',sans-serif;font-size:14px;background:#1c1b24;border:1px solid rgba(255,255,255,0.1);color:#e0dcf0;border-radius:10px;padding:11px 14px;transition:border-color 0.15s;"
          />
          <button
            type="submit"
            class="auth-btn"
            style="font-family:'DM Sans',sans-serif;font-size:14px;font-weight:500;background:#3d2f7a;color:#ddd8f0;border:1px solid rgba(180,160,240,0.25);border-radius:10px;padding:11px;cursor:pointer;transition:background 0.15s;margin-top:4px;"
          >
            Sign in
          </button>
        </form>

        <div style="margin-top:20px;font-size:13px;color:#3a3840;text-align:center;">
          No account?
          <a href="/register" style="color:#8b7faa;text-decoration:none;margin-left:4px;">
            Create one
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp put_session(socket, key, value) do
    push_event(socket, "put_session", %{key: key, value: value})
  end
end
