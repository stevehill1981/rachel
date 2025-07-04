defmodule Rachel.Games.AIPlayerEdgeCasesTest do
  @moduledoc """
  Edge case tests for AIPlayer to achieve 100% coverage.
  Focusing on the 3 uncovered lines.
  """
  use ExUnit.Case, async: true
  
  alias Rachel.Games.{Game, Card, AIPlayer}
  
  describe "edge cases for 100% coverage" do
    test "handles when opponents have many cards for reverse direction priority" do
      # Test line 96: :reverse_direction when length(game.players) > 2
      game = Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.start_game()
      
      # Set AI's turn
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 3}
      }
      
      # Give players specific card counts - opponents with many cards
      [p1, ai, p3, p4] = game.players
      # Keep p1 and p3 with many cards (more than 3), p4 with few
      p1 = %{p1 | hand: List.duplicate(%Card{suit: :spades, rank: 2}, 5)}
      p3 = %{p3 | hand: List.duplicate(%Card{suit: :clubs, rank: 3}, 4)}
      p4 = %{p4 | hand: [%Card{suit: :diamonds, rank: 4}]}  # Only 1 card
      
      # Give AI an 8 to test reverse priority
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 8}  # Reverse card
      ]}
      
      game = %{game | players: [p1, ai, p3, p4]}
      
      # The AI should consider the reverse card with its specific priority
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end
    
    test "handles choose_suit priority calculation" do
      # Test line 99-100: :choose_suit -> 30
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 3}
      }
      
      # Give AI only an ace to test choose_suit priority path
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :spades, rank: :ace}  # Only an ace
      ]}
      game = %{game | players: [human, ai]}
      
      # Should play the ace with its specific priority
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end
    
    test "handles fallback case in choose_best_suit with empty hand" do
      # Test line 128: [] -> :hearts
      # This is a defensive case that shouldn't normally happen, but we test it
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        nominated_suit: :pending
      }
      
      # Give AI empty hand to trigger fallback
      [human, ai] = game.players
      ai = %{ai | hand: []}
      game = %{game | players: [human, ai]}
      
      # Should return fallback suit
      assert {:nominate, :hearts} = AIPlayer.make_move(game, "ai")
    end
    
    test "special effect priorities when all opponents have many cards" do
      # Test lines 82-83 and 85-86 for special effects
      # count_opponents_with_many_cards counts players with <= 3 cards
      # When it returns 0, all opponents have > 3 cards
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 3}
      }
      
      # Give human many cards (more than 3) - this makes count return 0
      [human, ai] = game.players
      human = %{human | hand: List.duplicate(%Card{suit: :spades, rank: 2}, 5)}
      
      # Give AI special cards to test priority when count == 0
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 2},   # Pickup 2 - gets priority 70
        %Card{suit: :hearts, rank: 7}    # Skip - gets priority 65
      ]}
      game = %{game | players: [human, ai]}
      
      # AI should prefer pickup 2 (higher priority)
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end
    
    test "black jack priority when all opponents have many cards" do
      # Test line 89-90 for black jack priority when count == 0
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :jack}
      }
      
      # Give human many cards (> 3) to make count_opponents_with_many_cards == 0
      [human, ai] = game.players
      human = %{human | hand: List.duplicate(%Card{suit: :spades, rank: 2}, 5)}
      
      # Give AI a black jack when all opponents have many cards
      ai = %{ai | hand: [
        %Card{suit: :clubs, rank: :jack}  # Black jack - gets priority 75 when count == 0
      ]}
      game = %{game | players: [human, ai]}
      
      # Should play the black jack with high priority
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end
  end
  
  describe "red jack defensive priority" do
    test "red jack gets low priority when not under black jack attack" do
      # Test lines 91-93: red jacks get priority 30 when not defending
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :king}  # Not a jack
      }
      
      # Give AI a red jack and other cards
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: :jack},  # Red jack - should get low priority (30)
        %Card{suit: :hearts, rank: 5},      # Regular card - priority 50
        %Card{suit: :hearts, rank: 2}       # Pickup 2 - varies by opponent cards
      ]}
      game = %{game | players: [human, ai]}
      
      # Should prefer regular card or pickup 2 over red jack
      {:play, index} = AIPlayer.make_move(game, "ai")
      assert index in [1, 2]  # Not the red jack at index 0
    end
  end
end