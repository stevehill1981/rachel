defmodule RachelWeb.GameLiveMultiplayerTest do
  use RachelWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Rachel.Games.GameManager

  describe "GameLive multiplayer" do
    test "redirects to lobby when game not found", %{conn: conn} do
      # Should get a redirect error when trying to access nonexistent game
      assert {:error, {:live_redirect, %{to: "/lobby"}}} = live(conn, "/game/nonexistent-game")
    end

    test "can join an existing multiplayer game", %{conn: conn} do
      # Create a game first
      {:ok, game_id} = GameManager.create_and_join_game("creator", "GameCreator")

      # Try to join the game
      {:ok, _view, html} = live(conn, "/game/#{game_id}")

      # Should be in the game
      assert html =~ "Rachel"
      assert html =~ "GameCreator"

      # Clean up
      GameManager.stop_game(game_id)
    end

    test "handles game updates via PubSub", %{conn: conn} do
      # Create a game
      {:ok, game_id} = GameManager.create_and_join_game("creator", "GameCreator")

      # Join the game in the LiveView
      {:ok, view, _html} = live(conn, "/game/#{game_id}")

      # Add another player externally (simulates another user joining)
      GameManager.join_game(game_id, "player2", "SecondPlayer")

      # The view should receive the game update and show the new player
      # (This tests the PubSub subscription)
      # Allow time for PubSub message
      :timer.sleep(50)

      html = render(view)
      assert html =~ "SecondPlayer"

      # Clean up
      GameManager.stop_game(game_id)
    end

    test "single-player mode still works without game_id", %{conn: conn} do
      {:ok, view, html} = live(conn, "/game")

      # Should show the single-player game
      assert html =~ "Rachel"

      # Wait a moment for the game to initialize
      :timer.sleep(100)

      # Get the updated HTML after initialization
      html = render(view)

      # Check for game content - single player should have game elements
      assert html =~ "card" || html =~ "deck" || html =~ "hand"
    end
  end
end
