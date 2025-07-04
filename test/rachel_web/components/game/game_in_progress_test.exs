defmodule RachelWeb.Components.Game.GameInProgressTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  alias RachelWeb.Components.Game.GameInProgress
  alias Rachel.Games.{Game, Card, Player, Deck}
  
  # Define current_player function that the component imports
  defmodule RachelWeb.GameLive do
    def current_player(%{players: players, current_player_index: idx}) when idx >= 0 do
      Enum.at(players, idx)
    end
    def current_player(_), do: nil
  end
  
  describe "game_in_progress component" do
    setup do
      game = %Game{
        id: "test-game",
        status: :playing,
        deck: %Deck{cards: List.duplicate(%Card{suit: :hearts, rank: 2}, 10)},
        current_card: %Card{suit: :spades, rank: 3},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        players: [
          %Player{id: "p1", name: "Player 1", hand: [%Card{suit: :hearts, rank: 5}], is_ai: false},
          %Player{id: "p2", name: "Player 2", hand: [%Card{suit: :spades, rank: 6}], is_ai: false}
        ],
        current_player_index: 0,
        winners: [],
        nominated_suit: nil
      }
      
      {:ok, game: game}
    end
    
    test "renders game in progress for active player", %{game: game} do
      assigns = %{
        game: game,
        player_id: "p1",
        selected_cards: [],
        show_ai_thinking: false,
        is_spectator: false
      }
      
      html = render_component(&GameInProgress.game_in_progress/1, assigns)
      
      # Should render main components
      assert html =~ "Player 1"  # Players display
      assert html =~ "10"  # Deck size
      assert html =~ "5♥"  # Player's card
    end
    
    test "renders suit selector when nomination pending for current player", %{game: game} do
      # Set nominated suit to pending
      game = %{game | nominated_suit: :pending}
      
      assigns = %{
        game: game,
        player_id: "p1",
        selected_cards: [],
        show_ai_thinking: false,
        is_spectator: false
      }
      
      html = render_component(&GameInProgress.game_in_progress/1, assigns)
      
      # Should show suit selector component
      assert html =~ "Choose a Suit"
    end
    
    test "doesn't show suit selector for non-current player", %{game: game} do
      game = %{game | nominated_suit: :pending}
      
      assigns = %{
        game: game,
        player_id: "p2",  # Not current player
        selected_cards: [],
        show_ai_thinking: false,
        is_spectator: false
      }
      
      html = render_component(&GameInProgress.game_in_progress/1, assigns)
      
      # Should NOT show suit selector
      refute html =~ "Choose a Suit"
    end
    
    test "doesn't show suit selector for spectators", %{game: game} do
      game = %{game | nominated_suit: :pending}
      
      assigns = %{
        game: game,
        player_id: "p1",
        selected_cards: [],
        show_ai_thinking: false,
        is_spectator: true  # Spectator mode
      }
      
      html = render_component(&GameInProgress.game_in_progress/1, assigns)
      
      # Should NOT show suit selector for spectators
      refute html =~ "Choose a Suit"
    end
    
    test "handles game with AI thinking", %{game: game} do
      # Add AI player and make them current
      [p1, p2] = game.players
      ai_player = %Player{id: "ai1", name: "Computer", hand: [], is_ai: true}
      game = %{game | players: [p1, p2, ai_player], current_player_index: 2}
      
      assigns = %{
        game: game,
        player_id: "p1",
        selected_cards: [],
        show_ai_thinking: true,
        is_spectator: false
      }
      
      html = render_component(&GameInProgress.game_in_progress/1, assigns)
      
      # Should show AI thinking indicator
      assert html =~ "AI is thinking"
    end
    
    test "handles spectator view", %{game: game} do
      assigns = %{
        game: game,
        player_id: "spectator",
        selected_cards: [],
        show_ai_thinking: false,
        is_spectator: true
      }
      
      html = render_component(&GameInProgress.game_in_progress/1, assigns)
      
      # Should render spectator view
      assert html =~ "Spectating"
    end
  end
end