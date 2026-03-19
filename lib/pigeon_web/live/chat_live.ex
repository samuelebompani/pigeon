defmodule PigeonWeb.ChatLive do
  use PigeonWeb, :live_view

  alias Pigeon.Repo
  alias Pigeon.Pigeons.{PigeonServer, PigeonState}
  alias Pigeon.Pigeons.PigeonNames

  @personalities ["grumpy", "affectionate", "chaotic", "lazy", "dramatic"]

  # ──────────────────────────────────────────────────
  # Mount
  # ──────────────────────────────────────────────────

  def mount(%{"user" => other}, _session, socket) do
    me = socket.assigns.me
    topic = topic_for(me, other)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pigeon.PubSub, topic)
    end

    messages = load_messages(topic)
    pigeon = Repo.get_by(PigeonState, chat: topic)

    if connected?(socket) && pigeon && pigeon.status == "active" do
      pid =
        case PigeonServer.start_link(topic) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      Process.monitor(pid)
    end

    {:ok,
     socket
     |> stream(:messages, messages, reset: true)
     |> assign(:me, me)
     |> assign(:other, other)
     |> assign(:topic, topic)
     |> assign_pigeon(pigeon)
     |> assign(:message_input, "")}
  end

  # ──────────────────────────────────────────────────
  # Events
  # ──────────────────────────────────────────────────

  def handle_event("send_message", %{"message" => msg}, socket) do
    msg = String.trim(msg)

    if msg != "" do
      message =
        Repo.insert!(%Pigeon.Chats.Message{
          chat: socket.assigns.topic,
          username: socket.assigns.me,
          content: msg
        })

      Phoenix.PubSub.broadcast(
        Pigeon.PubSub,
        socket.assigns.topic,
        {:new_message, message}
      )
    end

    {:noreply, assign(socket, :message_input, "")}
  end

  def handle_event("request_adoption", _, socket) do
    Repo.insert!(%PigeonState{
      chat: socket.assigns.topic,
      owners: [socket.assigns.me, socket.assigns.other],
      status: "pending",
      hunger: 30,
      requested_by: socket.assigns.me
    })

    broadcast(socket, {:adoption_requested})
    {:noreply, socket}
  end

  def handle_event("accept_adoption", _, socket) do
    pigeon = Repo.get_by!(PigeonState, chat: socket.assigns.topic)

    pigeon =
      pigeon
      |> Ecto.Changeset.change(
        status: "active",
        personality: Enum.random(@personalities),
        name: PigeonNames.random()
      )
      |> Repo.update!()

    pid =
      case PigeonServer.start_link(socket.assigns.topic) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    Process.monitor(pid)

    broadcast(socket, {:adoption_accepted})
    {:noreply, assign_pigeon(socket, pigeon)}
  end

  def handle_event("decline_adoption", _, socket) do
    pigeon = Repo.get_by!(PigeonState, chat: socket.assigns.topic)
    Repo.delete!(pigeon)
    broadcast(socket, {:adoption_declined})
    {:noreply, assign_pigeon(socket, nil)}
  end

  def handle_event("feed_pigeon", _, socket) do
    PigeonServer.feed(socket.assigns.topic)
    {:noreply, socket}
  end

  # ──────────────────────────────────────────────────
  # PubSub
  # ──────────────────────────────────────────────────

  def handle_info({:new_message, msg}, socket) do
    {:noreply, stream_insert(socket, :messages, msg)}
  end

  def handle_info({:adoption_requested}, socket) do
    pigeon = Repo.get_by(PigeonState, chat: socket.assigns.topic)
    {:noreply, assign_pigeon(socket, pigeon)}
  end

  def handle_info({:adoption_accepted}, socket) do
    pigeon = Repo.get_by(PigeonState, chat: socket.assigns.topic)
    {:noreply, assign_pigeon(socket, pigeon)}
  end

  def handle_info({:adoption_declined}, socket) do
    {:noreply, assign_pigeon(socket, nil)}
  end

  def handle_info({:pigeon_update, %{hunger: hunger}}, socket) do
    {:noreply, assign(socket, :pigeon_hunger, hunger)}
  end

  def handle_info({:pigeon_gone}, socket) do
    {:noreply,
     socket
     |> assign(:pigeon_status, nil)
     |> assign(:pigeon_hunger, 0)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign_pigeon(socket, nil)}
  end

  # ──────────────────────────────────────────────────
  # Render
  # ──────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <style>
      @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500&family=DM+Mono:wght@400&display=swap');
      .pigeon-app { font-family: 'DM Sans', sans-serif; }
      .msg-input:focus { outline: none; border-color: rgba(180,160,240,0.35) !important; }
      .msg-input::placeholder { color: #3a3840; }
      .hunger-fill { transition: width 0.4s ease; }
      .feed-btn:hover { background: rgba(130,200,130,0.22) !important; }
      .send-btn:hover { background: #4d3f8a !important; }
      .adopt-btn:hover { background: rgba(180,160,240,0.18) !important; }
      .accept-btn:hover { background: rgba(130,200,130,0.22) !important; }
      .decline-btn:hover { background: rgba(220,100,100,0.22) !important; }
    </style>

    <div
      class="pigeon-app"
      style="background:#0f0f11;color:#e8e6df;height:100dvh;display:flex;flex-direction:column;"
    >

    <!-- Header -->
      <div style="padding:14px 18px;display:flex;align-items:center;gap:10px;border-bottom:1px solid rgba(255,255,255,0.07);background:#16161a;">
        <a
          href="/"
          style="width:28px;height:28px;border-radius:8px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);display:flex;align-items:center;justify-content:center;text-decoration:none;"
        >
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
            <path
              d="M7 2L3 6L7 10"
              stroke="#888"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </a>
        <div style="width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,#3d3550,#2a2040);border:1px solid rgba(255,255,255,0.12);display:flex;align-items:center;justify-content:center;font-size:13px;color:#c4b8f0;font-weight:500;">
          {String.upcase(String.slice(@other, 0, 1))}
        </div>
        <div>
          <div style="font-size:14px;font-weight:500;color:#eeeae0;">@{@other}</div>
        </div>
      </div>

    <!-- Pigeon Panel -->
      <div style="margin:12px 14px 0;">
        <%= if is_nil(@pigeon_status) do %>
          <button
            phx-click="request_adoption"
            class="adopt-btn"
            style="width:100%;font-family:'DM Sans',sans-serif;font-size:13px;font-weight:500;background:rgba(180,160,240,0.1);color:#c4b8f0;border:1px solid rgba(180,160,240,0.2);border-radius:10px;padding:10px 14px;cursor:pointer;text-align:left;transition:background 0.15s;"
          >
            🕊️ Adopt a pigeon together
          </button>
        <% else %>
          <%= if @pigeon_status == "pending" do %>
            <div style="background:#1c1a24;border:1px solid rgba(255,255,255,0.08);border-radius:12px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between;">
              <%= if @me != @other_requested do %>
                <div style="font-size:13px;color:#b0a8c8;">
                  🕊️ <b style="color:#ddd8f0;">{@other}</b> wants to adopt a pigeon
                </div>
                <div style="display:flex;gap:8px;">
                  <button
                    phx-click="accept_adoption"
                    class="accept-btn"
                    style="font-family:'DM Sans',sans-serif;font-size:12px;font-weight:500;background:rgba(130,200,130,0.12);color:#7dd08a;border:1px solid rgba(130,200,130,0.2);border-radius:7px;padding:5px 12px;cursor:pointer;transition:background 0.15s;"
                  >
                    Accept
                  </button>
                  <button
                    phx-click="decline_adoption"
                    class="decline-btn"
                    style="font-family:'DM Sans',sans-serif;font-size:12px;font-weight:500;background:rgba(220,100,100,0.1);color:#d08080;border:1px solid rgba(220,100,100,0.2);border-radius:7px;padding:5px 12px;cursor:pointer;transition:background 0.15s;"
                  >
                    Decline
                  </button>
                </div>
              <% else %>
                <div style="font-size:13px;color:#6b6460;">
                  🕊️ Waiting for <b style="color:#9088a8;">{@other}</b> to accept…
                </div>
              <% end %>
            </div>
          <% else %>
            <div style="background:#1c1a24;border:1px solid rgba(255,255,255,0.08);border-radius:12px;padding:12px 14px;">
              <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
                <div style="display:flex;align-items:center;gap:8px;">
                  <div style="width:28px;height:28px;border-radius:8px;background:rgba(255,220,100,0.12);border:1px solid rgba(255,220,100,0.2);display:flex;align-items:center;justify-content:center;font-size:14px;">
                    🕊️
                  </div>
                  <div>
                    <div style="font-size:13px;font-weight:500;color:#d4c8f0;">{@pigeon_name || "Your pigeon"}</div>
                    <div style="font-size:10px;color:#8b7faa;background:rgba(180,160,240,0.1);border:1px solid rgba(180,160,240,0.15);border-radius:4px;padding:1px 6px;text-transform:uppercase;letter-spacing:0.06em;display:inline-block;margin-top:2px;">
                      {@pigeon_personality}
                    </div>
                  </div>
                </div>
                <button
                  phx-click="feed_pigeon"
                  class="feed-btn"
                  style="font-family:'DM Sans',sans-serif;font-size:12px;font-weight:500;background:rgba(130,200,130,0.12);color:#7dd08a;border:1px solid rgba(130,200,130,0.2);border-radius:7px;padding:5px 12px;cursor:pointer;transition:background 0.15s;"
                >
                  Feed
                </button>
              </div>
              <div style="display:flex;align-items:center;gap:10px;">
                <div style="font-size:11px;color:#5a5850;min-width:42px;">Hunger</div>
                <div style="flex:1;height:3px;background:rgba(255,255,255,0.07);border-radius:99px;overflow:hidden;">
                  <div
                    class="hunger-fill"
                    style={"width:#{@pigeon_hunger}%;height:100%;background:linear-gradient(90deg,#e06060,#e08040);border-radius:99px;"}
                  >
                  </div>
                </div>
                <div style="font-size:11px;color:#5a5850;font-family:'DM Mono',monospace;min-width:28px;text-align:right;">
                  {@pigeon_hunger}
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

    <!-- Messages -->
      <div
        id="messages"
        phx-update="stream"
        phx-hook="ScrollBottom"
        style="flex:1;overflow-y:auto;padding:14px;display:flex;flex-direction:column;gap:8px;scrollbar-width:none;"
      >
        <div
          :for={{id, msg} <- @streams.messages}
          id={id}
          style={
            if msg.username == @me,
              do: "display:flex;gap:8px;flex-direction:row-reverse;",
              else: "display:flex;gap:8px;"
          }
        >
          <div style={avatar_style(msg.username, @me)}>
            <%= if msg.username == "🕊️ pigeon" do %>
              🕊
            <% else %>
              {String.upcase(String.slice(msg.username, 0, 1))}
            <% end %>
          </div>
          <div>
            <div style={bubble_style(msg.username, @me)}>
              {msg.content}
            </div>
          </div>
        </div>
      </div>

    <!-- Input -->
      <div style="padding:10px 14px 18px;display:flex;gap:8px;align-items:center;border-top:1px solid rgba(255,255,255,0.06);background:#16161a;">
        <form phx-submit="send_message" style="flex:1;display:flex;gap:8px;align-items:center;">
          <input
            name="message"
            value={@message_input}
            class="msg-input"
            placeholder={"Message @#{@other}…"}
            autocomplete="off"
            style="flex:1;font-family:'DM Sans',sans-serif;font-size:13px;background:#1c1b24;border:1px solid rgba(255,255,255,0.1);color:#e0dcf0;border-radius:10px;padding:9px 14px;"
          />
          <button
            type="submit"
            class="send-btn"
            style="width:36px;height:36px;border-radius:10px;background:#3d2f7a;border:1px solid rgba(180,160,240,0.25);cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;transition:background 0.15s;"
          >
            <svg width="14" height="14" viewBox="0 0 16 16" fill="#c0b0f0">
              <path d="M14 8L2 2l2.5 6L2 14l12-6z" />
            </svg>
          </button>
        </form>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────────

  defp topic_for(a, b) do
    [a, b] = Enum.sort([a, b])
    "dm:#{a}:#{b}"
  end

  defp load_messages(topic) do
    import Ecto.Query

    Repo.all(
      from(m in Pigeon.Chats.Message,
        where: m.chat == ^topic,
        order_by: [asc: m.inserted_at]
      )
    )
  end

  defp assign_pigeon(socket, nil) do
    socket
    |> assign(:pigeon_status, nil)
    |> assign(:pigeon_hunger, 0)
    |> assign(:pigeon_personality, nil)
    |> assign(:pigeon_name, nil)
    |> assign(:other_requested, nil)
  end

  defp assign_pigeon(socket, pigeon) do
    socket
    |> assign(:pigeon_status, pigeon.status)
    |> assign(:pigeon_hunger, pigeon.hunger)
    |> assign(:pigeon_personality, pigeon.personality)
    |> assign(:pigeon_name, pigeon.name)
    |> assign(:other_requested, pigeon.requested_by)
  end

  defp broadcast(socket, msg) do
    Phoenix.PubSub.broadcast(Pigeon.PubSub, socket.assigns.topic, msg)
  end

  defp bubble_style(username, me) do
    base = "max-width:280px;padding:8px 12px;font-size:13px;line-height:1.5;"

    cond do
      username == me ->
        base <>
          "background:#2d2650;border:1px solid rgba(180,160,240,0.15);color:#ddd8f0;border-radius:12px;border-bottom-right-radius:4px;"

      username == "🕊️ pigeon" ->
        base <>
          "background:rgba(255,220,100,0.08);border:1px solid rgba(255,220,100,0.15);color:#e8d87a;font-style:italic;border-radius:12px;border-bottom-left-radius:4px;"

      true ->
        base <>
          "background:#1e1d26;border:1px solid rgba(255,255,255,0.07);color:#ccc8be;border-radius:12px;border-bottom-left-radius:4px;"
    end
  end

  defp avatar_style(username, me) do
    base =
      "width:24px;height:24px;border-radius:50%;font-size:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:2px;"

    cond do
      username == me ->
        base <> "background:#2a2040;color:#b0a0e0;border:1px solid rgba(180,160,240,0.2);"

      username == "🕊️ pigeon" ->
        base <>
          "background:rgba(255,220,100,0.1);color:#c8b840;border:1px solid rgba(255,220,100,0.2);font-size:11px;"

      true ->
        base <> "background:#222028;color:#888;border:1px solid rgba(255,255,255,0.08);"
    end
  end
end
