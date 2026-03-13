defmodule PigeonWeb.ChatLiveTest do
  use PigeonWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  # async: false is required because Presence uses shared ETS tables

  describe "mount" do
    test "renders the lobby by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "# lobby"
      assert html =~ "Everyone can see this"
    end

    test "assigns a random username", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "User_"
    end
  end

  describe "lobby messaging" do
    test "sent message appears in sender's view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{message: "hello world"})
      |> render_submit()

      assert render(view) =~ "hello world"
    end

    test "empty message is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{message: "   "})
      |> render_submit()

      # no crash, view still alive
      assert render(view) =~ "# lobby"
    end

    test "message is broadcast to other subscribers", %{conn: conn} do
      {:ok, view_a, _} = live(conn, "/")
      {:ok, view_b, _} = live(conn, "/")

      view_a
      |> form("form", %{message: "hi from A"})
      |> render_submit()

      assert render(view_b) =~ "hi from A"
    end
  end

  describe "presence" do
    test "user appears in sidebar when another connects", %{conn: conn} do
      {:ok, view_a, _} = live(conn, "/")

      html_a = render(view_a)
      [_, username_a] = Regex.run(~r/font-mono truncate">(User_\d+)/, html_a)

      {:ok, _view_b, _} = live(conn, "/")

      assert render(view_a) =~ username_a
    end

    import ExUnit.CaptureLog
  end

  describe "direct messages" do
    test "opening a DM switches the chat header", %{conn: conn} do
      {:ok, view_a, _} = live(conn, "/")
      {:ok, _view_b, html_b} = live(conn, "/")

      [_, username_b] = Regex.run(~r/font-mono truncate">(User_\d+)/, html_b)

      view_a |> element("button[phx-value-user='#{username_b}']") |> render_click()

      assert render(view_a) =~ "@#{username_b}"
      assert render(view_a) =~ "Private conversation"
    end

    test "DM message reaches the other user but not lobby", %{conn: conn} do
      {:ok, view_a, html_a} = live(conn, "/")
      {:ok, view_b, html_b} = live(conn, "/")
      {:ok, view_c, _} = live(conn, "/")

      [_, username_a] = Regex.run(~r/font-mono truncate">(User_\d+)/, html_a)
      [_, username_b] = Regex.run(~r/font-mono truncate">(User_\d+)/, html_b)

      # A opens DM with B, B opens DM with A
      view_a |> element("button[phx-value-user='#{username_b}']") |> render_click()
      view_b |> element("button[phx-value-user='#{username_a}']") |> render_click()

      view_a
      |> form("form", %{message: "private message"})
      |> render_submit()

      assert render(view_b) =~ "private message"
      refute render(view_c) =~ "private message"
    end

    test "cannot open a DM with yourself", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      [_, username] = Regex.run(~r/font-mono truncate">(User_\d+)/, html)

      # self doesn't appear as a clickable DM target in the sidebar
      # (filtered out in the template with :if={user != @username})
      refute view |> element("button[phx-value-user='#{username}']") |> has_element?()
    end

    test "switching back to lobby restores lobby context", %{conn: conn} do
      {:ok, view_a, _} = live(conn, "/")
      {:ok, view_b, html_b} = live(conn, "/")

      [_, username_b] = Regex.run(~r/font-mono truncate">(User_\d+)/, html_b)

      view_a |> element("button[phx-value-user='#{username_b}']") |> render_click()
      view_a |> element("button", "# lobby") |> render_click()

      assert render(view_a) =~ "Everyone can see this"
    end
  end
end
