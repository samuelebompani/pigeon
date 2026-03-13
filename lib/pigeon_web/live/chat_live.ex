defmodule PigeonWeb.ChatLive do
  use PigeonWeb, :live_view
  alias Pigeon.Presence

  # ── Mount ────────────────────────────────────────────────────────────────────

  def mount(_params, _session, socket) do
    username = "User_#{:rand.uniform(1000)}"

    if connected?(socket) do
      # Track this user in the lobby presence
      {:ok, _} = Presence.track(self(), "lobby", username, %{joined_at: System.os_time(:second)})
      Phoenix.PubSub.subscribe(Pigeon.PubSub, "lobby")
    end

    online_users = list_users("lobby")

    {:ok,
     socket
     |> stream(:messages, [], reset: true)
     |> assign(:username, username)
     |> assign(:message_input, "")
     # :lobby or {:dm, "OtherUser"}
     |> assign(:chat, :lobby)
     |> assign(:online_users, online_users)}
  end

  # ── Events ───────────────────────────────────────────────────────────────────

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      topic = topic_for(socket.assigns.chat, socket.assigns.username)

      new_message = %{
        id: System.unique_integer([:positive]),
        username: socket.assigns.username,
        content: message,
        timestamp: DateTime.utc_now()
      }

      Phoenix.PubSub.broadcast(Pigeon.PubSub, topic, {:new_message, new_message})
    end

    {:noreply, assign(socket, :message_input, "")}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  def handle_event("open_dm", %{"user" => other_user}, socket) do
    %{username: me, chat: current_chat} = socket.assigns

    # Don't open a DM with yourself
    if other_user == me do
      {:noreply, socket}
    else
      new_chat = {:dm, other_user}

      # Unsubscribe from old topic, subscribe to new one
      old_topic = topic_for(current_chat, me)
      new_topic = topic_for(new_chat, me)

      Phoenix.PubSub.unsubscribe(Pigeon.PubSub, old_topic)
      Phoenix.PubSub.subscribe(Pigeon.PubSub, new_topic)

      {:noreply,
       socket
       |> stream(:messages, [], reset: true)
       |> assign(:chat, new_chat)}
    end
  end

  def handle_event("open_lobby", _, socket) do
    %{username: me, chat: current_chat} = socket.assigns
    old_topic = topic_for(current_chat, me)

    Phoenix.PubSub.unsubscribe(Pigeon.PubSub, old_topic)
    Phoenix.PubSub.subscribe(Pigeon.PubSub, "lobby")

    {:noreply,
     socket
     |> stream(:messages, [], reset: true)
     |> assign(:chat, :lobby)}
  end

  # ── Info ─────────────────────────────────────────────────────────────────────

  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", topic: "lobby"}, socket) do
    {:noreply, assign(socket, :online_users, list_users("lobby"))}
  end

  # Catch-all for any other presence or pubsub noise
  def handle_info(_other, socket) do
    {:noreply, socket}
  end

  # ── Render ───────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-100 font-sans">

    <!-- Sidebar -->
      <aside class="w-56 bg-gray-900 text-gray-100 flex flex-col">
        <div class="p-4 border-b border-gray-700">
          <h1 class="text-lg font-bold tracking-wide">🐦‍⬛ Pigeon</h1>
          <p class="text-xs text-gray-400 mt-1 font-mono truncate">{@username}</p>
        </div>

    <!-- Lobby button -->
        <div class="p-2">
          <button
            phx-click="open_lobby"
            class={[
              "w-full text-left px-3 py-2 rounded text-sm transition-colors",
              if @chat == :lobby do
                "bg-purple-600 text-white"
              else
                "text-gray-300 hover:bg-gray-700"
              end
            ]}
          >
            # lobby
          </button>
        </div>

    <!-- Online users -->
        <div class="px-4 py-2 text-xs font-semibold uppercase tracking-wider text-gray-500">
          Online — {length(@online_users)}
        </div>
        <ul class="flex-1 overflow-y-auto px-2 space-y-0.5">
          <li :for={user <- @online_users} :if={user != @username}>
            <button
              phx-click="open_dm"
              phx-value-user={user}
              class={[
                "w-full text-left px-3 py-2 rounded text-sm transition-colors flex items-center gap-2",
                if @chat == {:dm, user} do
                  "bg-purple-600 text-white"
                else
                  "text-gray-300 hover:bg-gray-700"
                end
              ]}
            >
              <span class="w-2 h-2 rounded-full bg-green-400 flex-shrink-0"></span>
              {user}
            </button>
          </li>
        </ul>
      </aside>

    <!-- Main chat area -->
      <div class="flex-1 flex flex-col">
        <!-- Chat header -->
        <header class="bg-white border-b px-6 py-3 flex items-center gap-3 shadow-sm">
          <div>
            <h2 class="font-semibold text-gray-800">
              {case @chat do
                :lobby -> "# lobby"
                {:dm, other} -> "@#{other}"
              end}
            </h2>
            <p class="text-xs text-gray-400">
              {case @chat do
                :lobby -> "Everyone can see this"
                {:dm, _} -> "Private conversation"
              end}
            </p>
          </div>
        </header>

    <!-- Messages -->
        <div class="flex-1 overflow-y-auto p-4 space-y-2" id="messages" phx-update="stream">
          <div
            :for={{dom_id, msg} <- @streams.messages}
            id={dom_id}
            class={[
              "p-3 rounded-xl max-w-sm",
              if msg.username == @username do
                "ml-auto bg-purple-600 text-white"
              else
                "bg-white text-gray-800 shadow-sm"
              end
            ]}
          >
            <div class="flex items-center gap-1.5 text-xs opacity-60 mb-1">
              <span class="font-medium">{msg.username}</span>
              <span>·</span>
              <span>{format_timestamp(msg.timestamp)}</span>
            </div>
            <p class="break-words text-sm leading-relaxed">{msg.content}</p>
          </div>
        </div>

    <!-- Input -->
        <div class="bg-white border-t px-4 py-3">
          <form phx-submit="send_message" class="flex gap-2">
            <input
              type="text"
              name="message"
              value={@message_input}
              placeholder={
                case @chat do
                  :lobby -> "Message everyone..."
                  {:dm, other} -> "Message @#{other}..."
                end
              }
              class="flex-1 px-4 py-2 bg-gray-100 rounded-full text-gray-900 text-sm
                     focus:outline-none focus:ring-2 focus:ring-purple-500"
              phx-change="update_message"
              autocomplete="off"
            />
            <button
              type="submit"
              class="bg-purple-600 text-white px-5 py-2 rounded-full text-sm
                     hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
              Send
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Lobby uses "lobby", DMs use a sorted topic so both users share the same channel
  defp topic_for(:lobby, _me), do: "lobby"

  defp topic_for({:dm, other}, me) do
    [a, b] = Enum.sort([me, other])
    "dm:#{a}:#{b}"
  end

  defp list_users(topic) do
    topic
    |> Presence.list()
    |> Map.keys()
  end

  defp format_timestamp(%DateTime{} = dt) do
    "#{dt.hour}:#{String.pad_leading("#{dt.minute}", 2, "0")}"
  end

  defp format_timestamp(_), do: ""
end
