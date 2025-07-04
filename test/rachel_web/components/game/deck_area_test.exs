defmodule RachelWeb.Components.Game.DeckAreaTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  alias RachelWeb.Components.Game.DeckArea
  alias Rachel.Games.{Game, Card, Player, Deck}
  
  describe "deck_area component" do
    setup do
      game = %Game{
        id: "test-game",
        deck: %Deck{cards: List.duplicate(%Card{suit: :hearts, rank: 2}, 10)},
        current_card: %Card{suit: :spades, rank: 3},
        discard_pile: [%Card{suit: :hearts, rank: 4}],
        pending_pickups: 0,
        pending_skips: 0,
        players: [
          %Player{id: "p1", name: "Human", hand: [], is_ai: false},
          %Player{id: "ai1", name: "Computer", hand: [], is_ai: true}
        ],
        current_player_index: 0
      }
      
      {:ok, game: game}
    end
    
    test "renders deck area with human player", %{game: game} do
      current_player = Enum.at(game.players, 0)
      
      assigns = %{
        game: game,
        player_id: "p1",
        show_ai_thinking: false,
        current_player: current_player
      }
      
      html = render_component(&DeckArea.deck_area/1, assigns)
      
      # Should show deck and current card
      assert html =~ "10"  # Deck size
      assert html =~ "3♠" # Current card
    end
    
    test "shows AI thinking indicator when AI is current player", %{game: game} do
      # Set AI as current player
      game = %{game | current_player_index: 1}
      current_player = Enum.at(game.players, 1)
      
      assigns = %{
        game: game,
        player_id: "p1",
        show_ai_thinking: true,
        current_player: current_player
      }
      
      html = render_component(&DeckArea.deck_area/1, assigns)
      
      # Should show AI thinking indicator
      assert html =~ "AI is thinking"
    end
    
    test "doesn't show AI thinking when human is current player", %{game: game} do
      current_player = Enum.at(game.players, 0)
      
      assigns = %{
        game: game,
        player_id: "p1", 
        show_ai_thinking: true,
        current_player: current_player
      }
      
      html = render_component(&DeckArea.deck_area/1, assigns)
      
      # Should NOT show AI thinking indicator for human
      refute html =~ "AI is thinking"
    end
    
    test "shows deck can be drawn when player has no valid play", %{game: game} do
      # Give player no valid cards
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :diamonds, rank: :king}]}
      game = %{game | players: [player | rest], current_card: %Card{suit: :hearts, rank: 2}}
      
      current_player = player
      
      assigns = %{
        game: game,
        player_id: "p1",
        show_ai_thinking: false,
        current_player: current_player
      }
      
      html = render_component(&DeckArea.deck_area/1, assigns)
      
      # Check that deck is rendered
      assert html =~ "Deck"
      assert html =~ "10"  # deck size
    end
    
    test "handles nil current_player gracefully", %{game: game} do
      assigns = %{
        game: game,
        player_id: "p1",
        show_ai_thinking: true,
        current_player: nil
      }
      
      html = render_component(&DeckArea.deck_area/1, assigns)
      
      # Should render without errors
      assert html =~ "10"  # deck size
      refute html =~ "AI is thinking"
    end
  end
end