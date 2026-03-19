# test/pigeon_web/live/chat_live_test.exs
defmodule PigeonWeb.ChatLiveTest do
  use PigeonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Pigeon.Accounts
  alias Pigeon.Repo
  alias Pigeon.Chats.Message

  setup do
    {:ok, alice} = Accounts.register(%{username: "alice_#{System.unique_integer([:positive])}", password: "secret"})
    {:ok, bob}   = Accounts.register(%{username: "bob_#{System.unique_integer([:positive])}", password: "secret"})
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

  describe "mount" do
    test "renders chat page for authenticated user", %{conn: conn, alice: alice, bob: bob} do
      conn = authed_conn(conn, alice)
      {:ok, _view, html} = live(conn, "/chat/#{bob.username}")
      assert html =~ "Chat with @#{bob.username}"
    end

    test "redirects to login when unauthenticated", %{conn: conn, bob: bob} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, "/chat/#{bob.username}")
    end

    test "loads existing messages on mount", %{conn: conn, alice: alice, bob: bob} do
      Repo.insert!(%Message{chat: topic(alice, bob), username: alice.username, content: "hello bob"})

      conn = authed_conn(conn, alice)
      {:ok, _view, html} = live(conn, "/chat/#{bob.username}")
      assert html =~ "hello bob"
    end
  end

  describe "send_message" do
    test "broadcasts and displays a new message", %{conn: conn, alice: alice, bob: bob} do
      conn = authed_conn(conn, alice)
      {:ok, view, _html} = live(conn, "/chat/#{bob.username}")

      view |> form("form", %{message: "hey there"}) |> render_submit()

      assert render(view) =~ "hey there"
    end

    test "ignores blank messages", %{conn: conn, alice: alice, bob: bob} do
      conn = authed_conn(conn, alice)
      {:ok, view, _html} = live(conn, "/chat/#{bob.username}")

      view |> form("form", %{message: "   "}) |> render_submit()

      assert Repo.all(from m in Message, where: m.chat == ^topic(alice, bob)) == []
    end

    test "clears input after send", %{conn: conn, alice: alice, bob: bob} do
      conn = authed_conn(conn, alice)
      {:ok, view, _html} = live(conn, "/chat/#{bob.username}")

      view |> form("form", %{message: "hello"}) |> render_submit()

      refute render(view) =~ ~s(value="hello")
    end
  end
end
