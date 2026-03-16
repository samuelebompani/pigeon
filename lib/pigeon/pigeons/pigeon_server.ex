defmodule Pigeon.Pigeons.PigeonServer do
  use GenServer

  # Client API

  def start_link(topic) do
    GenServer.start_link(__MODULE__, topic, name: via(topic))
  end

  def feed(topic) do
    GenServer.cast(via(topic), :feed)
  end

  def whereis(topic) do
    case Registry.lookup(Pigeon.PigeonRegistry, topic) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  def pigeon_alive?(topic) do
    whereis(topic) != nil
  end

  def get_hunger(topic) do
    case whereis(topic) do
      pid when is_pid(pid) ->
        GenServer.call(pid, :get_hunger)
      nil ->
        {:error, :no_pigeon}
    end
  end

  def remove_pigeon(topic) do
    case whereis(topic) do
      pid when is_pid(pid) ->
        GenServer.cast(pid, :remove_yourself)
      nil ->
        :ok
    end
  end

  def spawn_or_replace_pigeon(topic) do
    # Remove existing pigeon if any
    remove_pigeon(topic)

    # Small delay to ensure cleanup
    Process.sleep(100)

    # Spawn new pigeon
    case start_link(topic) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  # GenServer Callbacks

  def via(topic) do
    {:via, Registry, {Pigeon.PigeonRegistry, topic}}
  end

  def init(topic) do
    schedule_tick()
    schedule_disappearance_check()

    {:ok,
     %{
       topic: topic,
       hunger: 30,
       created_at: System.system_time(:second)
     }}
  end

  def handle_call(:get_hunger, _from, state) do
    {:reply, state.hunger, state}
  end

  def handle_cast(:feed, state) do
    hunger = max(state.hunger - 40, 0)

    broadcast_chat(state.topic, "🕊️ pigeon", "peck peck (thank you)")
    broadcast_state(state.topic, hunger)

    {:noreply, %{state | hunger: hunger}}
  end

  def handle_cast(:remove_yourself, state) do
    # Broadcast farewell message
    broadcast_chat(state.topic, "🕊️ pigeon", "coo coo... goodbye!")

    # Stop the process
    {:stop, :normal, state}
  end

  def handle_info(:tick, state) do
    hunger = min(state.hunger + 5, 100)

    if :rand.uniform(100) < hunger do
      speak(state.topic)
    end

    broadcast_state(state.topic, hunger)

    schedule_tick()

    {:noreply, %{state | hunger: hunger}}
  end

  def handle_info(:check_disappearance, state) do
    # 20% chance to disappear if hunger is high
    if state.hunger > 80 and :rand.uniform(5) == 1 do
      # Pigeon flies away
      broadcast_chat(state.topic, "🕊️ pigeon", "coo... I'm flying away!")

      # Clear the pigeon state from database
      case Pigeon.Repo.get_by(Pigeon.Pigeons.PigeonState, chat: state.topic) do
        nil -> :ok
        existing -> Pigeon.Repo.delete(existing)
      end

      # Stop the process
      {:stop, :normal, state}
    else
      schedule_disappearance_check()
      {:noreply, state}
    end
  end

  def terminate(_reason, state) do
    # Clean up database state when pigeon terminates
    case Pigeon.Repo.get_by(Pigeon.Pigeons.PigeonState, chat: state.topic) do
      nil -> :ok
      existing -> Pigeon.Repo.delete(existing)
    end
    :ok
  end

  # Private functions

  defp speak(topic) do
    msg =
      Enum.random([
        "coo",
        "coo coo",
        "flap flap",
        "peck peck",
        "cooooo"
      ])

    broadcast_chat(topic, "🕊️ pigeon", msg)
  end

  defp broadcast_chat(topic, user, content) do
    message = %Pigeon.Chats.Message{
      chat: topic,
      username: user,
      content: content
    }

    inserted_message = Pigeon.Repo.insert!(message)

    Phoenix.PubSub.broadcast(Pigeon.PubSub, topic, {:new_message, inserted_message})
  end

  defp broadcast_state(topic, hunger) do
    changeset =
      case Pigeon.Repo.get_by(Pigeon.Pigeons.PigeonState, chat: topic) do
        nil ->
          %Pigeon.Pigeons.PigeonState{}
          |> Ecto.Changeset.cast(%{chat: topic, hunger: hunger}, [:chat, :hunger])

        existing_state ->
          existing_state
          |> Ecto.Changeset.cast(%{hunger: hunger}, [:hunger])
      end

    Pigeon.Repo.insert_or_update!(changeset)
    Phoenix.PubSub.broadcast(Pigeon.PubSub, topic, {:pigeon_update, %{hunger: hunger}})
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 8_000)
  end

  defp schedule_disappearance_check do
    Process.send_after(self(), :check_disappearance, 30_000) # Check every 30 seconds
  end
end
