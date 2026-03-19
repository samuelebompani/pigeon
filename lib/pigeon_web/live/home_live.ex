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
    <style>
      @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500&family=DM+Mono:wght@400&display=swap');
      .pigeon-app { font-family: 'DM Sans', sans-serif; }
      .user-row:hover { background: rgba(255,255,255,0.05) !important; }
      .logout-btn:hover { color: #c4b8f0 !important; }
    </style>

    <div class="pigeon-app" style="background:#0f0f11;color:#e8e6df;min-height:100dvh;display:flex;flex-direction:column;align-items:center;justify-content:flex-start;padding:48px 20px;">
      <div style="width:100%;max-width:360px;">

        <!-- Logo -->
        <div style="margin-bottom:36px;">
          <div style="font-size:24px;font-weight:500;color:#eeeae0;letter-spacing:-0.02em;">🕊️ Pigeon</div>
          <div style="font-size:13px;color:#4a4840;margin-top:4px;">
            Logged in as <span style="color:#8b7faa;font-family:'DM Mono',monospace;font-size:12px;">{@me}</span>
          </div>
        </div>

        <!-- User list -->
        <div style="margin-bottom:12px;font-size:11px;color:#3a3840;text-transform:uppercase;letter-spacing:0.1em;font-weight:500;">
          People
        </div>
        <div style="display:flex;flex-direction:column;gap:4px;">
          <%= for user <- @users do %>

            <a  href={"/chat/#{user}"}
              class="user-row"
              style="display:flex;align-items:center;gap:12px;padding:10px 12px;border-radius:10px;text-decoration:none;transition:background 0.12s;border:1px solid transparent;"
            >
              <div style="width:34px;height:34px;border-radius:50%;background:linear-gradient(135deg,#3d3550,#2a2040);border:1px solid rgba(255,255,255,0.1);display:flex;align-items:center;justify-content:center;font-size:13px;color:#c4b8f0;font-weight:500;flex-shrink:0;">
                {String.upcase(String.slice(user, 0, 1))}
              </div>
              <div style="font-size:14px;color:#ccc8be;">@{user}</div>
              <div style="margin-left:auto;">
                <svg width="14" height="14" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 2.5L8 6L4.5 9.5" stroke="#3a3840" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </div>
            </a>
          <% end %>
        </div>

        <!-- Logout -->
        <div style="margin-top:40px;padding-top:24px;border-top:1px solid rgba(255,255,255,0.06);">
          <form action="/logout" method="post">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <input type="hidden" name="_method" value="delete" />
            <button
              class="logout-btn"
              style="font-family:'DM Sans',sans-serif;background:none;border:none;font-size:13px;color:#3a3840;cursor:pointer;padding:0;transition:color 0.15s;"
            >
              Sign out
            </button>
          </form>
        </div>

      </div>
    </div>
    """
  end
end
