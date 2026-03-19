# lib/pigeon_web/live/register_live.ex
defmodule PigeonWeb.RegisterLive do
  use PigeonWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, socket}

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
          <div style="font-size:13px;color:#4a4840;">Create an account</div>
        </div>

        <form action="/register" method="post" style="display:flex;flex-direction:column;gap:10px;">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input
            name="username"
            placeholder="Username"
            class="auth-input"
            style="font-family:'DM Sans',sans-serif;font-size:14px;background:#1c1b24;border:1px solid rgba(255,255,255,0.1);color:#e0dcf0;border-radius:10px;padding:11px 14px;transition:border-color 0.15s;"
          />
          <input
            name="password"
            type="password"
            placeholder="Password"
            class="auth-input"
            style="font-family:'DM Sans',sans-serif;font-size:14px;background:#1c1b24;border:1px solid rgba(255,255,255,0.1);color:#e0dcf0;border-radius:10px;padding:11px 14px;transition:border-color 0.15s;"
          />
          <button
            type="submit"
            class="auth-btn"
            style="font-family:'DM Sans',sans-serif;font-size:14px;font-weight:500;background:#3d2f7a;color:#ddd8f0;border:1px solid rgba(180,160,240,0.25);border-radius:10px;padding:11px;cursor:pointer;transition:background 0.15s;margin-top:4px;"
          >
            Create account
          </button>
        </form>

        <div style="margin-top:20px;font-size:13px;color:#3a3840;text-align:center;">
          Already have an account?
          <a href="/login" style="color:#8b7faa;text-decoration:none;margin-left:4px;">Sign in</a>
        </div>
      </div>
    </div>
    """
  end
end
