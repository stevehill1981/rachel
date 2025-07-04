defmodule Rachel.Games.AIPlayerTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{Game, Card, AIPlayer}
  alias Test.AITestHelper

  describe "make_move/2" do
    setup do
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "Computer", true)
        |> Game.start_game()
      
      {:ok, game: game}
    end

    test "returns error when not AI player's turn", %{game: game} do
      # Set human's turn
      game = %{game | current_player_index: 0}
      
      assert {:error, :not_ai_turn} = AIPlayer.make_move(game, "ai")
    end

    test "returns error when player not found", %{game: game} do
      # AIPlayer checks if current player matches the requested player_id first
      # So we get :not_ai_turn for unknown players
      assert {:error, :not_ai_turn} = AIPlayer.make_move(game, "unknown")
    end

    test "returns valid move even when player is not AI", %{game: game} do
      # AIPlayer actually doesn't check if player is AI, it just provides the best move
      # This is intentional so it can provide hints for human players
      game = %{game | current_player_index: 0}
      
      # Should return a valid move (draw since human has no valid plays with starting hand)
      result = AIPlayer.make_move(game, "human")
      assert match?({:draw, nil}, result) || match?({:play, _}, result)
    end

    test "plays ace when available and no other valid plays", %{game: _game} do
      # Using AITestHelper for cleaner setup
      game = AITestHelper.ai_scenario(:play_ace, "ai")
      
      assert {:play, 0} = AITestHelper.ai_move(game, "ai")
    end

    test "prefers non-ace cards over aces", %{game: game} do
      # Set AI's turn
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :king}
      }
      
      # Give AI an ace and a matching card
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 3},  # Matches suit - index 0
        %Card{suit: :spades, rank: :ace}  # Ace - index 1
      ]}
      game = %{game | players: [human, ai]}
      
      # Should play the 3 of hearts (index 0), not the ace (index 1)
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "plays special effect cards strategically", %{game: game} do
      # Set AI's turn
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 3}
      }
      
      # Give AI multiple valid options including special cards
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 2},   # Pickup 2
        %Card{suit: :hearts, rank: 7},   # Skip
        %Card{suit: :hearts, rank: 8},   # Reverse
        %Card{suit: :hearts, rank: 10}   # Normal card
      ]}
      game = %{game | players: [human, ai]}
      
      # AI should prefer special effect cards
      {:play, index} = AIPlayer.make_move(game, "ai")
      assert index in [0, 1, 2]  # One of the special cards
    end

    test "stacks 2s when pending pickups", %{game: game} do
      # Set AI's turn with pending 2s
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 2,
        pending_pickup_type: :twos
      }
      
      # Give AI a 2 to stack
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :hearts, rank: 3}  # Can't play this
      ]}
      game = %{game | players: [human, ai]}
      
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "draws when no valid plays", %{game: game} do
      # Set AI's turn
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :king}
      }
      
      # Give AI no valid cards
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :clubs, rank: 3}
      ]}
      game = %{game | players: [human, ai]}
      
      assert {:draw, nil} = AIPlayer.make_move(game, "ai")
    end

    test "draws when forced by pending pickups", %{game: game} do
      # Set AI's turn with pending pickups it can't counter
      game = %{game | 
        current_player_index: 1,
        pending_pickups: 4,
        pending_pickup_type: :twos
      }
      
      # Give AI no 2s
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 3},
        %Card{suit: :spades, rank: :king}
      ]}
      game = %{game | players: [human, ai]}
      
      assert {:draw, nil} = AIPlayer.make_move(game, "ai")
    end

    test "nominates suit after playing ace", %{game: game} do
      # Set AI's turn with pending suit nomination
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :pending
      }
      
      # AI should nominate based on their hand
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :spades, rank: 3},
        %Card{suit: :clubs, rank: 4}
      ]}
      game = %{game | players: [human, ai]}
      
      # Should nominate spades (most common in hand)
      assert {:nominate, :spades} = AIPlayer.make_move(game, "ai")
    end

    test "plays black jack when strategic", %{game: game} do
      # Set AI's turn
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :jack}
      }
      
      # Give AI a black jack
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :spades, rank: :jack},  # Black jack
        %Card{suit: :hearts, rank: 2}       # Alternative
      ]}
      game = %{game | players: [human, ai]}
      
      # Should play the black jack for pickup 5 effect
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "uses red jack to cancel black jack", %{game: game} do
      # Set AI's turn with pending black jack pickups
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :spades, rank: :jack},
        pending_pickups: 5,
        pending_pickup_type: :black_jacks
      }
      
      # Give AI a red jack to cancel
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: :jack},  # Red jack cancels
        %Card{suit: :clubs, rank: 2}        # Can't play
      ]}
      game = %{game | players: [human, ai]}
      
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "respects nominated suit", %{game: game} do
      # Set AI's turn with nominated suit
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :clubs
      }
      
      # Give AI cards including the nominated suit
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 2},   # Wrong suit
        %Card{suit: :clubs, rank: 3},    # Correct suit
        %Card{suit: :spades, rank: :ace} # Ace always valid
      ]}
      game = %{game | players: [human, ai]}
      
      # Should play clubs (index 1) or ace (index 2)
      {:play, index} = AIPlayer.make_move(game, "ai")
      assert index in [1, 2]
    end

    test "plays 7 to skip opponent when beneficial", %{game: game} do
      # Two player game, AI's turn
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 3}
      }
      
      # Give AI a 7 and alternative
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 7},   # Skip
        %Card{suit: :hearts, rank: 10}   # Normal
      ]}
      game = %{game | players: [human, ai]}
      
      # Should prefer the 7 to skip opponent
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "plays 8 to reverse direction strategically" do
      # Create 3-player game for direction to matter
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "Computer", true)
        |> Game.add_player("ai2", "Computer 2", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        current_card: %Card{suit: :hearts, rank: 3},
        direction: :clockwise
      }
      
      # Give AI an 8 and alternative
      [human, ai, ai2] = game.players
      ai = %{ai | hand: [
        %Card{suit: :hearts, rank: 8},   # Reverse
        %Card{suit: :hearts, rank: 10}   # Normal
      ]}
      game = %{game | players: [human, ai, ai2]}
      
      # Should consider playing the 8
      {:play, index} = AIPlayer.make_move(game, "ai")
      assert index in [0, 1]
    end
  end

  describe "suit nomination strategy" do
    test "nominates most common suit in hand" do
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "Computer", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        nominated_suit: :pending
      }
      
      [human, ai] = game.players
      ai = %{ai | hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :spades, rank: 3},
        %Card{suit: :spades, rank: 4},
        %Card{suit: :hearts, rank: 5},
        %Card{suit: :clubs, rank: 6}
      ]}
      game = %{game | players: [human, ai]}
      
      # Should nominate spades (3 cards)
      assert {:nominate, :spades} = AIPlayer.make_move(game, "ai")
    end

    test "picks any suit when hand is empty after ace" do
      game = Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "Computer", true)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 1,
        nominated_suit: :pending
      }
      
      # AI has no cards left (just played last ace)
      [human, ai] = game.players
      ai = %{ai | hand: []}
      game = %{game | players: [human, ai]}
      
      # Should nominate any valid suit
      {:nominate, suit} = AIPlayer.make_move(game, "ai")
      assert suit in [:hearts, :diamonds, :clubs, :spades]
    end
  end
end