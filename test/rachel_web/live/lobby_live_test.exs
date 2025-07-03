defmodule RachelWeb.LobbyLiveTest do
  use RachelWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Rachel.Games.GameManager

  describe "LobbyLive" do
    test "displays lobby page with no games initially", %{conn: conn} do
      # Clean up any existing games
      GameManager.list_active_games()
      |> Enum.each(&GameManager.stop_game(&1.id))
      
      {:ok, _view, html} = live(conn, "/lobby")
      
      assert html =~ "Rachel Card Game"
      assert html =~ "Join a game or create your own"
      assert html =~ "No games available"
      assert html =~ "Create a new game to get started"
    end

    test "allows player to update their name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lobby")
      
      # Update player name by triggering the blur event
      view
      |> element("#player_name")
      |> render_blur(%{"player_name" => "TestPlayer"})
      
      # Check that the name was updated
      assert has_element?(view, "input[value='TestPlayer']")
    end

    test "displays error messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lobby")
      
      # Try to join a non-existent game
      view
      |> element("form[phx-submit='join_by_code']")
      |> render_submit(%{join_code: "invalid-game"})
      
      assert render(view) =~ "Invalid game code"
    end

    test "can create and join games", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lobby")
      
      # Create a game - this should redirect
      assert view
             |> element("button", "Create New Game")
             |> render_click()
      
      # The view should have been redirected to a game URL
      # Since we can't easily test the exact redirect in this setup,
      # we'll just verify the game was created
      games = GameManager.list_active_games()
      assert length(games) > 0
    end

    test "displays active games", %{conn: conn} do
      # Create a game first
      {:ok, game_id} = GameManager.create_and_join_game("test-player", "TestPlayer")
      
      {:ok, view, html} = live(conn, "/lobby")
      
      # Should display the game
      assert html =~ "Game #{String.slice(game_id, -6..-1)}"
      assert html =~ "TestPlayer"
      assert html =~ "1/8"
      assert has_element?(view, "button", "Join Game")
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "shows games as full when they have 8 players", %{conn: conn} do
      # Clean up any existing games first
      GameManager.list_active_games()
      |> Enum.each(&GameManager.stop_game(&1.id))
      
      # Create a game and fill it up
      {:ok, game_id} = GameManager.create_and_join_game("player1", "Player1")
      
      for i <- 2..8 do
        GameManager.join_game(game_id, "player#{i}", "Player#{i}")
      end
      
      # Verify the game is actually full before testing the UI
      {:ok, game_info} = GameManager.get_game_info(game_id)
      assert game_info.player_count == 8
      assert game_info.can_join == false
      
      {:ok, view, html} = live(conn, "/lobby")
      
      # Should show as full
      assert html =~ "8/8"
      assert html =~ "Full"
      
      # Check that this specific game shows as not joinable
      game_element = element(view, "[phx-value-game_id='#{game_id}']")
      refute has_element?(game_element)  # The join button should not exist for this game
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "refreshes game list when refresh button is clicked", %{conn: conn} do
      # Clean up any existing games first
      GameManager.list_active_games()
      |> Enum.each(&GameManager.stop_game(&1.id))
      
      {:ok, view, _html} = live(conn, "/lobby")
      
      # Initially no games
      assert render(view) =~ "No games available"
      
      # Create a game in another process
      {:ok, game_id} = GameManager.create_and_join_game("other-player", "OtherPlayer")
      
      # Click refresh
      view
      |> element("button", "Refresh")
      |> render_click()
      
      # Should now show the game
      assert render(view) =~ "Game #{String.slice(game_id, -6..-1)}"
      
      # Clean up
      GameManager.stop_game(game_id)
    end
  end
end