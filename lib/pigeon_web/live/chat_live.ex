defmodule PigeonWeb.ChatLive do
  use PigeonWeb, :live_view

  alias Pigeon.Repo
  alias Pigeon.Pigeons.{PigeonServer, PigeonState}

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
        personality: Enum.random(@personalities)
      )
      |> Repo.update!()

    PigeonServer.start_link(socket.assigns.topic)

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

  # ──────────────────────────────────────────────────
  # Render
  # ──────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col text-black bg-gray-100">

    <!-- Header -->
      <header class="p-4 border-b bg-white flex justify-between items-center">
        <div class="font-semibold text-lg">
          Chat with @{@other}
        </div>
      </header>

    <!-- Pigeon Panel -->
      <div class="p-4 border-b bg-yellow-50">
        <%= if is_nil(@pigeon_status) do %>
          <button
            phx-click="request_adoption"
            class="bg-yellow-400 px-4 py-2 rounded shadow"
          >
            🐦 Adopt a pigeon together
          </button>
        <% else %>
          <%= if @pigeon_status == "pending" do %>
            <div class="flex items-center justify-between">
              <%= if @me != @other_requested do %>
                <span>🐦 <b>{@other}</b> wants to adopt a pigeon together!</span>
                <div class="flex gap-2">
                  <button
                    phx-click="accept_adoption"
                    class="bg-green-500 text-white px-3 py-1 rounded"
                  >
                    Accept
                  </button>
                  <button
                    phx-click="decline_adoption"
                    class="bg-red-400 text-white px-3 py-1 rounded"
                  >
                    Decline
                  </button>
                </div>
              <% else %>
                <span>🐦 Adoption request sent, waiting for <b>{@other}</b>...</span>
              <% end %>
            </div>
          <% else %>
            <div class="space-y-3">
              <div class="flex items-center justify-between">
                <div class="text-sm">
                  🕊️ <b>{@pigeon_personality}</b> pigeon
                </div>
                <button
                  phx-click="feed_pigeon"
                  class="bg-green-500 text-white px-3 py-1 rounded text-sm"
                >
                  Feed
                </button>
              </div>

    <!-- Hunger bar -->
              <div>
                <div class="text-xs text-gray-600 mb-1">Hunger</div>
                <div class="w-full bg-gray-200 h-2 rounded">
                  <div
                    class="bg-red-400 h-2 rounded transition-all"
                    style={"width: #{@pigeon_hunger}%"}
                  >
                  </div>
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
        class="flex-1 overflow-y-auto p-4 space-y-2"
      >
        <div
          :for={{id, msg} <- @streams.messages}
          id={id}
          class={[
            "p-3 rounded-xl max-w-sm",
            msg.username == @me && "ml-auto bg-purple-600 text-white",
            msg.username == "🕊️ pigeon" && "bg-yellow-200",
            msg.username != @me && msg.username != "🕊️ pigeon" && "bg-white shadow"
          ]}
        >
          <div class="text-xs opacity-60 mb-1">{msg.username}</div>
          <div>{msg.content}</div>
        </div>
      </div>

    <!-- Input -->
      <form phx-submit="send_message" class="p-3 bg-white border-t flex gap-2">
        <input
          name="message"
          value={@message_input}
          class="flex-1 border rounded px-3 py-2"
          autocomplete="off"
        />
        <button class="bg-purple-600 text-white px-4 rounded">Send</button>
      </form>
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
    |> assign(:other_requested, nil)
  end

  defp assign_pigeon(socket, pigeon) do
    socket
    |> assign(:pigeon_status, pigeon.status)
    |> assign(:pigeon_hunger, pigeon.hunger)
    |> assign(:pigeon_personality, pigeon.personality)
    |> assign(:other_requested, pigeon.requested_by)
  end

  defp broadcast(socket, msg) do
    Phoenix.PubSub.broadcast(Pigeon.PubSub, socket.assigns.topic, msg)
  end
end
