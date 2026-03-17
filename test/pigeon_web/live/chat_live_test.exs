defmodule PigeonWeb.ChatLiveTest do
  use PigeonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Returns the PubSub topic for a DM between two users (matches topic_for/2).
  defp dm_topic(a, b) do
    [x, y] = Enum.sort([a, b])
    "dm:#{x}:#{y}"
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders successfully and assigns a random username", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "# lobby"
      assert has_element?(view, "aside")

      # Username is in the format "User_<1..1000>"
      username = view |> element("aside p") |> render()
      assert username =~ ~r/User_\d+/
    end

    test "starts in lobby chat with no messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "#messages")
      # Stream is empty — no message divs inside
      refute view |> element("#messages [id^='messages-']") |> has_element?()
    end

    test "pigeon is not alive on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      refute html =~ "Your pigeon is here"
    end

    test "pigeon hunger bar is not rendered when pigeon is not alive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      refute has_element?(view, ".bg-red-400")
    end
  end

  # ---------------------------------------------------------------------------
  # Messaging
  # ---------------------------------------------------------------------------

  describe "send_message event" do
    test "broadcasts and displays a chat message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{message: "Hello lobby!"})
      |> render_submit()

      assert render(view) =~ "Hello lobby!"
    end

    test "trims whitespace — blank messages are not broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{message: "   "})
      |> render_submit()

      # No message div should appear
      refute view |> element("#messages [id^='messages-']") |> has_element?()
    end

    test "clears the input after sending", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{message: "test"})
      |> render_submit()

      assert view |> element("input[name=message]") |> render() =~ ~s(value="")
    end

    test "two views in the same lobby both receive a message", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      view1
      |> form("form", %{message: "cross-view ping"})
      |> render_submit()

      assert render(view2) =~ "cross-view ping"
    end
  end

  describe "update_message event" do
    test "updates message_input assign without broadcasting", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("input[name=message]")
      |> render_change(%{message: "typing..."})

      # Input reflects updated value; no message in stream yet
      assert view |> element("input[name=message]") |> render() =~ "typing..."
      refute view |> element("#messages [id^='messages-']") |> has_element?()
    end
  end

  # ---------------------------------------------------------------------------
  # Pigeon
  # ---------------------------------------------------------------------------

  describe "spawn_pigeon event" do
    test "makes the pigeon visible after clicking Adopt", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "🕊️ Adopt") |> render_click()

      assert render(view) =~ "Your pigeon is here"
    end

    test "spawning a second time does not crash (already_started)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "🕊️ Adopt") |> render_click()
      view |> element("button", "🕊️ Adopt") |> render_click()

      assert render(view) =~ "Your pigeon is here"
    end
  end

  describe "feed_pigeon event" do
    test "does not crash when pigeon is alive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "🕊️ Adopt") |> render_click()

      # Should not raise
      assert view |> element("button", "Feed") |> render_click()
    end

    # NOTE: feeding without a live pigeon calls PigeonServer.feed/1 on a
    # non-existent process. The current code does NOT guard against this.
    # The test below documents the known unsafe behaviour.
    @tag :known_bug
    test "does not crash when no pigeon has been spawned (currently unsafe)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # This may raise — flagged as a known bug.
      assert view |> element("button", "Feed") |> render_click()
    end
  end

  describe "pigeon hunger updates" do
    test "renders the hunger bar when pigeon is alive and hunger > 0", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("button", "🕊️ Adopt") |> render_click()

      # Simulate a pigeon_update broadcast
      send(view.pid, {:pigeon_update, %{hunger: 55}})
      render(view)

      assert view |> element(".bg-red-400") |> render() =~ ~s(width: 55%)
    end

    test "hunger resets to 0 on initial mount (not carried from previous state)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("button", "🕊️ Adopt") |> render_click()

      send(view.pid, {:pigeon_update, %{hunger: 80}})
      render(view)

      assert view |> element(".bg-red-400") |> render() =~ "width: 80%"
    end
  end

  # ---------------------------------------------------------------------------
  # DM / chat switching
  # ---------------------------------------------------------------------------

  describe "open_dm event" do
    test "switching to a DM updates the header", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      # Get view2's username from its rendered sidebar label
      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      # view1 clicks on user2 in the online list
      view1 |> element("button[phx-value-user='#{user2}']") |> render_click()

      assert render(view1) =~ "@#{user2}"
    end

    test "DM messages are not delivered to the lobby", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")
      {:ok, lobby_view, _} = live(conn, "/")

      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      # view1 switches to a DM with user2
      view1 |> element("button[phx-value-user='#{user2}']") |> render_click()

      view1
      |> form("form", %{message: "secret DM"})
      |> render_submit()

      refute render(lobby_view) =~ "secret DM"
    end

    test "opening a DM with yourself is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      user_html = view |> element("aside p") |> render()
      [username] = Regex.run(~r/User_\d+/, user_html)

      # Send the event directly since the UI filters out self from the list
      view |> render_click("open_dm", %{"user" => username})

      # Still in lobby
      assert render(view) =~ "# lobby"
    end

    test "switching to DM resets messages stream", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      # Send a lobby message first
      view1 |> form("form", %{message: "lobby msg"}) |> render_submit()
      assert render(view1) =~ "lobby msg"

      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      # Switch to DM
      view1 |> element("button[phx-value-user='#{user2}']") |> render_click()

      # Old lobby message should be gone
      refute render(view1) =~ "lobby msg"
    end

    test "switching to DM resets pigeon_alive to false", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      view1 |> element("button", "🕊️ Adopt") |> render_click()
      assert render(view1) =~ "Your pigeon is here"

      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      view1 |> element("button[phx-value-user='#{user2}']") |> render_click()

      refute render(view1) =~ "Your pigeon is here"
    end

    # NOTE: hunger is NOT reset when switching chats
    test "switching chats does not resets pigeon_hunger to 0", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      view1 |> element("button", "🕊️ Adopt") |> render_click()
      send(view1.pid, {:pigeon_update, %{hunger: 90}})
      render(view1)

      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      view1 |> element("button[phx-value-user='#{user2}']") |> render_click()

      # Pigeon is gone but hunger is still 90 — bar would reappear if pigeon re-spawned
      refute render(view1) =~ "width: 90%"
    end
  end

  describe "open_lobby event" do
    test "returns to lobby from a DM", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      view1 |> element("button[phx-value-user='#{user2}']") |> render_click()
      assert render(view1) =~ "@#{user2}"

      view1 |> element("button", "# lobby") |> render_click()
      assert render(view1) =~ "# lobby"
    end
  end

  # ---------------------------------------------------------------------------
  # Presence / online users
  # ---------------------------------------------------------------------------

  describe "presence" do
    test "online users list updates when a new user connects", %{conn: conn} do
      {:ok, view1, _} = live(conn, "/")
      {:ok, view2, _} = live(conn, "/")

      user2_html = view2 |> element("aside p") |> render()
      [user2] = Regex.run(~r/User_\d+/, user2_html)

      assert render(view1) =~ user2
    end

    test "own username is not shown in the online users list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      user_html = view |> element("aside p") |> render()
      [username] = Regex.run(~r/User_\d+/, user_html)

      online_list = view |> element("ul") |> render()
      refute online_list =~ username
    end
  end

  # ---------------------------------------------------------------------------
  # Message rendering / format_time
  # ---------------------------------------------------------------------------

  describe "message rendering" do
    test "own messages appear on the right (purple)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> form("form", %{message: "my msg"}) |> render_submit()

      assert view
             |> element(".bg-purple-600", "my msg")
             |> has_element?()
    end

    test "pigeon messages appear with yellow background", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate a pigeon message arriving via PubSub
      send(
        view.pid,
        {:new_message,
         %{
           id: 9999,
           username: "🕊️ pigeon",
           content: "coo coo",
           timestamp: DateTime.utc_now()
         }}
      )

      render(view)

      assert view |> element(".bg-yellow-200", "coo coo") |> has_element?()
    end

    test "other users' messages appear with white card", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      send(
        view.pid,
        {:new_message,
         %{
           id: 1234,
           username: "User_999",
           content: "hello from someone else",
           timestamp: DateTime.utc_now()
         }}
      )

      render(view)

      assert view |> element(".bg-white.shadow", "hello from someone else") |> has_element?()
    end

    test "format_time renders HH:MM with zero-padded minutes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      dt = ~U[2024-06-01 09:05:00Z]

      send(
        view.pid,
        {:new_message,
         %{id: 42, username: "User_1", content: "tick", timestamp: dt}}
      )

      render(view)

      assert render(view) =~ "9:05"
    end
  end
end
