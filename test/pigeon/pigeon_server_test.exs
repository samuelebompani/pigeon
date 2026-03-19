defmodule Pigeon.PigeonServerTest do
  use Pigeon.DataCase, async: false

  alias Pigeon.Repo
  alias Pigeon.Pigeons.{PigeonServer, PigeonState}

  setup do
    n = System.unique_integer([:positive])
    topic = "dm:alice_#{n}:bob_#{n}"

    Repo.insert!(%PigeonState{
      chat: topic,
      owners: ["alice_#{n}", "bob_#{n}"],
      status: "active",
      hunger: 30,
      personality: "affectionate",
      requested_by: "alice_#{n}"
    })

    Phoenix.PubSub.subscribe(Pigeon.PubSub, topic)

    {:ok, pid} = PigeonServer.start_link(topic)
    Ecto.Adapters.SQL.Sandbox.allow(Pigeon.Repo, self(), pid)

    # wait for handle_continue to finish loading from DB
    Process.sleep(100)

    # if the process crashed during handle_continue it won't be alive
    assert Process.alive?(pid),
           "PigeonServer crashed after start — likely a sandbox DB error in handle_continue"

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    %{topic: topic, pid: pid}
  end

  describe "feed/1" do
    test "reduces hunger by 40", %{topic: topic} do
      Repo.get_by!(PigeonState, chat: topic)
      |> Ecto.Changeset.change(hunger: 80)
      |> Repo.update!()

      GenServer.stop(PigeonServer.via(topic))
      {:ok, _} = PigeonServer.start_link(topic)

      PigeonServer.feed(topic)

      assert_receive {:pigeon_update, %{hunger: hunger}}, 1000
      assert hunger == 40
    end

    test "hunger does not go below 0", %{topic: topic} do
      PigeonServer.feed(topic)
      assert_receive {:pigeon_update, %{hunger: _}}, 1000
      PigeonServer.feed(topic)
      assert_receive {:pigeon_update, %{hunger: hunger}}, 1000
      assert hunger == 0
    end

    test "broadcasts a chat message on feed", %{topic: topic} do
      PigeonServer.feed(topic)
      assert_receive {:new_message, %{content: "peck peck ❤️"}}, 1000
    end
  end

  '''
  describe "tick" do
    test "increases hunger over time", %{topic: topic} do
      initial = Repo.get_by!(PigeonState, chat: topic).hunger
      send(PigeonServer.via(topic), :tick)
      assert_receive {:pigeon_update, %{hunger: hunger}}, 1000
      assert hunger == initial + 5
    end

    test "hunger does not exceed 100", %{topic: topic} do
      Repo.get_by!(PigeonState, chat: topic)
      |> Ecto.Changeset.change(hunger: 100)
      |> Repo.update!()

      GenServer.stop(PigeonServer.via(topic))
      {:ok, new_pid} = PigeonServer.start_link(topic)
      Ecto.Adapters.SQL.Sandbox.allow(Pigeon.Repo, self(), new_pid)

      send(PigeonServer.via(topic), :tick)
      assert_receive {:pigeon_update, %{hunger: hunger}}, 1000
      assert hunger == 100
    end

    test "persists hunger to DB after tick", %{topic: topic} do
      send(PigeonServer.via(topic), :tick)
      assert_receive {:pigeon_update, %{hunger: _}}, 1000

      pigeon = Repo.get_by!(PigeonState, chat: topic)
      assert pigeon.hunger == 35
    end
  end
  '''
end
