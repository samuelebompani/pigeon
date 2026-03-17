defmodule Pigeon.Pigeons.PigeonServer do
  use GenServer

  alias Pigeon.Repo
  alias Pigeon.Pigeons.PigeonState

  @max_hunger 100

  # ──────────────────────────────────────────────────
  # API
  # ──────────────────────────────────────────────────

  def start_link(topic) do
    GenServer.start_link(__MODULE__, topic, name: via(topic))
  end

  def feed(topic) do
    GenServer.cast(via(topic), :feed)
  end

  def via(topic) do
    {:via, Registry, {Pigeon.PigeonRegistry, topic}}
  end

  # ──────────────────────────────────────────────────
  # Init
  # ──────────────────────────────────────────────────

  def init(topic) do
    pigeon = Repo.get_by!(PigeonState, chat: topic)

    schedule_tick()

    {:ok,
     %{
       topic: topic,
       hunger: pigeon.hunger,
       personality: pigeon.personality
     }}
  end

  # ──────────────────────────────────────────────────
  # Calls / Casts
  # ──────────────────────────────────────────────────

  def handle_cast(:feed, state) do
    hunger = max(state.hunger - 40, 0)

    broadcast_chat(state, "peck peck ❤️")
    persist(state.topic, hunger)

    {:noreply, %{state | hunger: hunger}}
  end

  # ──────────────────────────────────────────────────
  # Tick
  # ──────────────────────────────────────────────────

  def handle_info(:tick, state) do
    hunger = min(state.hunger + 5, @max_hunger)

    if :rand.uniform(100) < hunger do
      speak(state)
    end

    persist(state.topic, hunger)
    schedule_tick()

    {:noreply, %{state | hunger: hunger}}
  end

  # ──────────────────────────────────────────────────
  # Behavior
  # ──────────────────────────────────────────────────

  defp speak(state) do
    msg =
      case state.personality do
        "grumpy" -> "hmph"
        "affectionate" -> "coo ❤️"
        "chaotic" -> "COO???"
        "lazy" -> "...coo"
        "dramatic" -> "I am fading..."
      end

    broadcast_chat(state, msg)
  end

  # ──────────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────────

  defp broadcast_chat(state, msg) do
    message =
      Repo.insert!(%Pigeon.Chats.Message{
        chat: state.topic,
        username: "🕊️ pigeon",
        content: msg
      })

    Phoenix.PubSub.broadcast(
      Pigeon.PubSub,
      state.topic,
      {:new_message, message}
    )
  end

  defp persist(topic, hunger) do
    pigeon = Repo.get_by!(PigeonState, chat: topic)

    pigeon
    |> Ecto.Changeset.change(hunger: hunger)
    |> Repo.update!()

    Phoenix.PubSub.broadcast(
      Pigeon.PubSub,
      topic,
      {:pigeon_update, %{hunger: hunger}}
    )
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 8_000)
  end
end
