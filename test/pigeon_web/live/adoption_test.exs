defmodule PigeonWeb.AdoptionTest do
  use PigeonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Pigeon.Accounts
  alias Pigeon.Repo
  alias Pigeon.Pigeons.PigeonState

  setup do
    n = System.unique_integer([:positive])
    {:ok, alice} = Accounts.register(%{username: "alice_#{n}", password: "secret"})
    {:ok, bob}   = Accounts.register(%{username: "bob_#{n}",   password: "secret"})
    %{alice: alice, bob: bob}
  end

  defp authed_conn(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> put_session(:username, user.username)
  end

  defp topic(alice, bob) do
    [a, b] = Enum.sort([alice.username, bob.username])
    "dm:#{a}:#{b}"
  end

  defp get_pigeon(alice, bob) do
    Repo.get_by(PigeonState, chat: topic(alice, bob))
  end

  describe "request_adoption" do
    test "requester sees waiting message", %{conn: conn, alice: alice, bob: bob} do
      conn = authed_conn(conn, alice)
      {:ok, view, _html} = live(conn, "/chat/#{bob.username}")

      render_click(view, "request_adoption")

      assert render(view) =~ "Adoption request sent"
      assert render(view) =~ bob.username
    end

    test "other user sees accept and decline buttons", %{conn: conn, alice: alice, bob: bob} do
      conn_a = authed_conn(conn, alice)
      {:ok, alice_view, _} = live(conn_a, "/chat/#{bob.username}")
      render_click(alice_view, "request_adoption")

      conn_b = authed_conn(build_conn(), bob)
      {:ok, bob_view, _} = live(conn_b, "/chat/#{alice.username}")

      assert render(bob_view) =~ "Accept"
      assert render(bob_view) =~ "Decline"
    end

    test "requester cannot see accept button", %{conn: conn, alice: alice, bob: bob} do
      conn = authed_conn(conn, alice)
      {:ok, view, _} = live(conn, "/chat/#{bob.username}")
      render_click(view, "request_adoption")

      refute render(view) =~ "Accept"
    end
  end

  describe "accept_adoption" do
    setup %{conn: conn, alice: alice, bob: bob} do
      conn_a = authed_conn(conn, alice)
      {:ok, alice_view, _} = live(conn_a, "/chat/#{bob.username}")
      render_click(alice_view, "request_adoption")

      conn_b = authed_conn(build_conn(), bob)
      {:ok, bob_view, _} = live(conn_b, "/chat/#{alice.username}")

      %{alice_view: alice_view, bob_view: bob_view}
    end

    test "pigeon becomes active after accept", %{bob_view: bob_view, alice: alice, bob: bob} do
      render_click(bob_view, "accept_adoption")

      pigeon = get_pigeon(alice, bob)
      assert pigeon.status == "active"
      assert pigeon.personality in ~w(grumpy affectionate chaotic lazy dramatic)
    end

    test "both users see the active pigeon panel", %{alice_view: alice_view, bob_view: bob_view} do
      render_click(bob_view, "accept_adoption")

      assert render(bob_view)   =~ "Feed"
      assert render(alice_view) =~ "Feed"
    end
  end

  describe "decline_adoption" do
    test "removes pigeon state and resets both views", %{conn: conn, alice: alice, bob: bob} do
      conn_a = authed_conn(conn, alice)
      {:ok, alice_view, _} = live(conn_a, "/chat/#{bob.username}")
      render_click(alice_view, "request_adoption")

      conn_b = authed_conn(build_conn(), bob)
      {:ok, bob_view, _} = live(conn_b, "/chat/#{alice.username}")
      render_click(bob_view, "decline_adoption")

      assert is_nil(get_pigeon(alice, bob))
      assert render(bob_view)   =~ "Adopt a pigeon together"
      assert render(alice_view) =~ "Adopt a pigeon together"
    end
  end
end
