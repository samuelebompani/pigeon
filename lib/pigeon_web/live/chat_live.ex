defmodule PigeonWeb.ChatLive do
  use PigeonWeb, :live_view

  def mount(_params, _session, socket) do
    username = "User_#{:rand.uniform(1000)}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pigeon.PubSub, "chat")
    end

    # Initialize with empty messages using streams
    # Important: Don't also assign :messages separately
    {:ok,
     socket
     |> stream(:messages, [], reset: true)
     |> assign(:username, username)
     |> assign(:message_input, "")
     |> assign(:crypto_ready, true)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      new_message = %{
        id: System.unique_integer([:positive]),
        username: socket.assigns.username,
        content: message,
        timestamp: DateTime.utc_now()
      }

      # Broadcast to all subscribers
      Phoenix.PubSub.broadcast(Pigeon.PubSub, "chat", {:new_message, new_message})
    end

    {:noreply, assign(socket, :message_input, "")}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  def handle_info({:new_message, message}, socket) do
    # Insert the new message into the stream
    # at: 0 puts it at the beginning (top of the list)
    # But since we render in order, this will show newest at the top
    # If you want newest at the bottom, remove at: 0
    {:noreply, stream_insert(socket, :messages, message)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-gray-200">
      <header class="bg-purple-600 text-white p-4 shadow-md">
        <h1 class="text-2xl font-bold">🐦‍⬛ Pigeon</h1>
        <p class="text-sm opacity-90">Logged in as: <span class="font-mono"><%= @username %></span></p>
      </header>

      <div class="flex-1 overflow-y-auto p-4 space-y-2" id="messages" phx-update="stream">
        <div
          :for={{dom_id, msg} <- @streams.messages}
          id={dom_id}
          class={[
            "p-3 rounded-lg max-w-md",
            if msg.username == @username do
              "ml-auto bg-purple-500 text-white"
            else
              "bg-white text-gray-800"
            end
          ]}
        >
          <div class="flex items-center gap-2 text-xs opacity-75 mb-1">
            <span><%= msg.username %></span>
            <span>•</span>
            <span><%= format_timestamp(msg.timestamp) %></span>
          </div>
          <p class="break-words"><%= msg.content %></p>
        </div>
      </div>

      <div class="bg-white border-t p-4">
        <form phx-submit="send_message" class="flex gap-2">
          <input
            type="text"
            name="message"
            value={@message_input}
            placeholder="Type your message..."
            class="text-gray-900 flex-1 px-4 py-2 border rounded-full focus:outline-none focus:ring-2 focus:ring-purple-500"
            phx-change="update_message"
            autocomplete="off"
          />
          <button
            type="submit"
            class="bg-purple-600 text-white px-6 py-2 rounded-full hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
          >
            Send
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp format_timestamp(%DateTime{} = dt) do
    "#{dt.hour}:#{String.pad_leading("#{dt.minute}", 2, "0")}"
  end
  defp format_timestamp(_), do: ""
end
