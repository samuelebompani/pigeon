defmodule PigeonWeb.ChatLive do
  use PigeonWeb, :live_view
  alias Pigeon.Presence
  alias Pigeon.Pigeons.PigeonServer
  alias Pigeon.Repo
  alias Pigeon.Pigeons.PigeonState

  # ──────────────────────────────────────────────────
  # Mount
  # ──────────────────────────────────────────────────

  def mount(_params, _session, socket) do
    username = "User_#{:rand.uniform(1000)}"

    if connected?(socket) do
      {:ok, _} = Presence.track(self(), "lobby", username, %{joined_at: System.os_time(:second)})
      Phoenix.PubSub.subscribe(Pigeon.PubSub, "lobby")
    end

    online_users = list_users("lobby")

    # Determine current topic
    chat = :lobby
    topic = topic_for(chat, username)

    # Load messages from DB
    import Ecto.Query, only: [from: 2]

    messages =
      Repo.all(
        from(m in Pigeon.Chats.Message,
          where: m.chat == ^topic,
          order_by: [asc: m.inserted_at]
        )
      )

    # Check if pigeon exists for this topic
    {pigeon_alive, pigeon_hunger} = check_pigeon_status(topic)

    {:ok,
     socket
     |> stream(:messages, messages, reset: true)
     |> assign(:username, username)
     |> assign(:message_input, "")
     |> assign(:chat, chat)
     |> assign(:online_users, online_users)
     |> assign(:pigeon_alive, pigeon_alive)
     |> assign(:pigeon_hunger, pigeon_hunger)}
  end

  # ──────────────────────────────────────────────────
  # Events
  # ──────────────────────────────────────────────────

  def handle_event("send_message", %{"message" => msg}, socket) do
    msg = String.trim(msg)

    if msg != "" do
      topic = current_topic(socket)

      # Create the message struct
      message = %Pigeon.Chats.Message{
        chat: current_topic(socket),
        username: socket.assigns.username,
        content: msg
      }

      # IMPORTANT: Use the returned record from insert! which has inserted_at set
      inserted_message = Repo.insert!(message)

      # Broadcast the inserted message (with inserted_at populated)
      Phoenix.PubSub.broadcast(
        Pigeon.PubSub,
        topic,
        {:new_message, inserted_message}
      )
    end

    {:noreply, assign(socket, :message_input, "")}
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    {:noreply, assign(socket, :message_input, msg)}
  end

  def handle_event("spawn_pigeon", _, socket) do
    topic = current_topic(socket)

    case PigeonServer.start_link(topic) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ignore
    end

    {:noreply, assign(socket, :pigeon_alive, true)}
  end

  def handle_event("feed_pigeon", _, socket) do
    PigeonServer.feed(current_topic(socket))
    {:noreply, socket}
  end

  def handle_event("open_dm", %{"user" => other}, socket) do
    if other == socket.assigns.username do
      {:noreply, socket}
    else
      {:noreply, switch_chat(socket, {:dm, other})}
    end
  end

  def handle_event("open_lobby", _, socket) do
    {:noreply, switch_chat(socket, :lobby)}
  end

  # ──────────────────────────────────────────────────
  # PubSub
  # ──────────────────────────────────────────────────

  def handle_info({:new_message, msg}, socket) do
    {:noreply, stream_insert(socket, :messages, msg)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :online_users, list_users("lobby"))}
  end

  def handle_info({:pigeon_update, %{hunger: hunger}}, socket) do
    {:noreply, assign(socket, :pigeon_hunger, hunger)}
  end

  # Handle case when pigeon disappears
  def handle_info({:pigeon_gone, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:pigeon_alive, false)
     |> assign(:pigeon_hunger, 0)}
  end

  # ──────────────────────────────────────────────────
  # Render
  # ──────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-100 text-black">

    <!-- Sidebar -->
      <aside class="w-56 bg-gray-900 text-gray-200 flex flex-col">
        <div class="p-4 border-b border-gray-700">
          <h1 class="text-lg font-bold">🐦 Pigeon</h1>
          <p class="text-xs opacity-60">{@username}</p>
        </div>

        <button
          phx-click="open_lobby"
          class="p-3 hover:bg-gray-700 text-left"
        >
          # lobby
        </button>

        <div class="px-3 text-xs uppercase opacity-60 mt-4">
          Online
        </div>

        <ul>
          <li :for={user <- @online_users} :if={user != @username}>
            <button
              phx-click="open_dm"
              phx-value-user={user}
              class="w-full text-left px-3 py-2 hover:bg-gray-700"
            >
              ● {user}
            </button>
          </li>
        </ul>
      </aside>

    <!-- Chat -->
      <div class="flex-1 flex flex-col">

    <!-- Header -->
        <header class="bg-white border-b p-4 flex justify-between items-center">
          <div class="font-semibold">
            {case @chat do
              :lobby -> "# lobby"
              {:dm, other} -> "@#{other}"
            end}
          </div>

          <div class="flex gap-2">
            <button
              phx-click="spawn_pigeon"
              class="bg-yellow-400 px-3 py-1 rounded text-sm"
            >
              🕊️ Adopt
            </button>

            <button
              phx-click="feed_pigeon"
              class="bg-green-500 text-white px-3 py-1 rounded text-sm"
            >
              Feed
            </button>
          </div>
        </header>

    <!-- Pigeon -->
        <div
          :if={@pigeon_alive}
          class="bg-yellow-100 border-b p-3 text-sm flex items-center gap-2"
        >
          🕊️ Your pigeon is here
        </div>
        <div :if={@pigeon_alive} class="bg-yellow-100 border-b p-3">
          <div class="flex items-center gap-3">
            <div class="flex-1">
              <div class="text-xs text-gray-600">Pigeon hunger</div>

              <div class="w-full bg-gray-200 rounded h-2 mt-1">
                <div
                  class="bg-red-400 h-2 rounded"
                  style={"width: #{@pigeon_hunger}%"}
                >
                </div>
              </div>
            </div>
          </div>
        </div>

    <!-- Messages -->
        <div
          id="messages"
          phx-update="stream"
          class="flex-1 overflow-y-auto p-4 space-y-2"
        >
          <div
            :for={{id, msg} <- @streams.messages}
            id={id}
            class={[
              "p-3 rounded-xl max-w-sm",
              msg.username == @username && "ml-auto bg-purple-600 text-white",
              msg.username == "🕊️ pigeon" && "bg-yellow-200",
              msg.username != @username && msg.username != "🕊️ pigeon" && "bg-white shadow"
            ]}
          >
            <div class="text-xs opacity-60 mb-1">
              {msg.username} · {format_time(msg.inserted_at || msg.timestamp)}
            </div>

            <div>
              {msg.content}
            </div>
          </div>
        </div>

    <!-- Input -->
        <form
          phx-submit="send_message"
          class="border-t p-3 flex gap-2 bg-white"
        >
          <input
            name="message"
            value={@message_input}
            phx-change="update_message"
            class="flex-1 border rounded px-3 py-2"
            autocomplete="off"
          />

          <button class="bg-purple-600 text-white px-4 rounded">
            Send
          </button>
        </form>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────────

  defp current_topic(socket) do
    topic_for(socket.assigns.chat, socket.assigns.username)
  end

  defp topic_for(:lobby, _), do: "lobby"

  defp topic_for({:dm, other}, me) do
    [a, b] = Enum.sort([me, other])
    "dm:#{a}:#{b}"
  end

  defp switch_chat(socket, chat) do
    me = socket.assigns.username

    old = topic_for(socket.assigns.chat, me)
    new = topic_for(chat, me)

    Phoenix.PubSub.unsubscribe(Pigeon.PubSub, old)
    Phoenix.PubSub.subscribe(Pigeon.PubSub, new)

    # Check pigeon status for the new topic
    {pigeon_alive, pigeon_hunger} = check_pigeon_status(new)

    socket
    |> assign(:chat, chat)
    |> assign(:pigeon_alive, pigeon_alive)
    |> assign(:pigeon_hunger, pigeon_hunger)
    |> stream(:messages, [], reset: true)
  end

  defp check_pigeon_status(topic) do
    case PigeonServer.whereis(topic) do
      pid when is_pid(pid) ->
        # Pigeon process exists, get its hunger
        case PigeonServer.get_hunger(topic) do
          {:ok, hunger} -> {true, hunger}
          {:error, :no_pigeon} -> {false, 0}
        end
      nil ->
        # No pigeon process, check if there's saved state
        case Repo.get_by(PigeonState, chat: topic) do
          nil -> {false, 0}
          %{hunger: hunger} -> {true, hunger}
        end
    end
  end

  defp list_users(topic) do
    topic
    |> Presence.list()
    |> Map.keys()
  end

  defp format_time(nil), do: ""
  defp format_time(%NaiveDateTime{} = dt), do: "#{dt.hour}:#{String.pad_leading("#{dt.minute}", 2, "0")}"
  defp format_time(%DateTime{} = dt), do: "#{dt.hour}:#{String.pad_leading("#{dt.minute}", 2, "0")}"
end
