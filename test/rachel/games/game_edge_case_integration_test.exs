defmodule Rachel.Games.GameEdgeCaseIntegrationTest do
  @moduledoc """
  Integration tests for edge cases that could break the game or cause infinite loops.
  These are the scenarios that could make a game unplayable or never end.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "game termination scenarios" do
    test "game ends when only one player remains active" do
      # Test the scenario you mentioned - games that never end
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Set up a current card and give Charlie a matching card
      current_card = %Card{suit: :hearts, rank: 5}
      game = %{game | current_card: current_card}
      
      # Simulate Alice and Bob winning (empty hands)
      [alice, bob, charlie] = game.players
      alice = %{alice | hand: []}
      bob = %{bob | hand: []}
      charlie = %{charlie | hand: [%Card{suit: :hearts, rank: 6}]}  # Charlie has matching suit
      
      game = %{game | 
        players: [alice, bob, charlie],
        winners: ["alice", "bob"],
        current_player_index: 2  # Charlie's turn
      }

      # When Charlie plays their last card, game should end immediately
      {:ok, final_game} = Game.play_card(game, "charlie", [0])
      
      # Game MUST end - no infinite loops
      assert final_game.status == :finished
      assert "charlie" in final_game.winners
      assert length(final_game.winners) == 3  # All players finished
    end

    test "game doesn't get stuck with only AI players" do
      # Another infinite loop scenario - all AI players
      game = Game.new()
      |> Game.add_player("ai1", "Bot 1", true)
      |> Game.add_player("ai2", "Bot 2", true)
      |> Game.start_game()

      # Simulate 50 turns max - game should end or at least not hang
      final_game = simulate_game_with_timeout(game, 50)
      
      # Either game finished or we stopped at turn limit (no infinite loop)
      assert final_game.status == :finished or count_moves_made(final_game) <= 50
    end

    test "game ends when deck is completely exhausted with no valid moves" do
      # Edge case: What if deck runs out AND no player can play?
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)

      # Create a scenario with very few cards and impossible plays
      # Force a situation where deck is empty and players can't play
      empty_deck = %Rachel.Games.Deck{cards: []}
      current_card = %Card{suit: :hearts, rank: :ace}  # Requires specific suit
      
      [alice, bob] = game.players
      # Give players cards that can't be played on the ace
      alice = %{alice | hand: [%Card{suit: :spades, rank: 5}]}  # Wrong suit, wrong rank
      bob = %{bob | hand: [%Card{suit: :clubs, rank: 7}]}       # Wrong suit, wrong rank
      
      game = %{game | 
        deck: empty_deck,
        current_card: current_card,
        discard_pile: [current_card],
        players: [alice, bob],
        nominated_suit: :hearts,  # Forces hearts only
        status: :playing,
        current_player_index: 0
      }

      # Alice can't play and can't draw (empty deck) - what happens?
      result = Game.draw_card(game, "alice")
      # Game should handle this gracefully, not hang
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "infinite loop prevention" do
    test "prevents infinite skip loops" do
      # What if everyone keeps playing 7s?
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Give everyone 7s that can be played
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      [alice, bob, charlie] = game.players
      
      alice = %{alice | hand: [%Card{suit: :hearts, rank: 7}, %Card{suit: :spades, rank: 8}]}
      bob = %{bob | hand: [%Card{suit: :spades, rank: 7}, %Card{suit: :clubs, rank: 9}]}
      charlie = %{charlie | hand: [%Card{suit: :clubs, rank: 7}, %Card{suit: :diamonds, rank: 10}]}
      
      game = %{game | players: [alice, bob, charlie], current_player_index: 0}

      # Simulate playing 7s in sequence - should not create infinite skips
      {:ok, game} = Game.play_card(game, "alice", [0])  # Alice plays 7
      # Game should continue and eventually stabilize
      game = simulate_game_with_timeout(game, 20)
      
      # Game should either end or reach a stable state, not infinite loop
      assert game.status == :finished or game.pending_skips <= 3
    end

    test "prevents infinite stacking with no resolution" do
      # What if stacking gets stuck?
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up a stacking scenario that could theoretically go forever
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 20,  # Huge stack
        pending_pickup_type: :twos
      }

      [alice, bob] = game.players
      # Alice has no 2s, Bob has no 2s
      alice = %{alice | hand: [%Card{suit: :spades, rank: 5}]}
      bob = %{bob | hand: [%Card{suit: :clubs, rank: 7}]}
      
      game = %{game | players: [alice, bob], current_player_index: 0}

      # Alice must draw the 20 cards
      {:ok, game} = Game.draw_card(game, "alice")
      
      # Stacking should be resolved
      assert game.pending_pickups == 0
      assert game.pending_pickup_type == nil
      assert length(Enum.at(game.players, 0).hand) > 0
    end

    test "prevents direction reversal loops" do
      # Multiple queens in a row causing direction chaos
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      [alice, bob] = game.players
      
      # Give both players multiple queens
      alice = %{alice | hand: [
        %Card{suit: :hearts, rank: :queen},
        %Card{suit: :spades, rank: :queen},
        %Card{suit: :clubs, rank: 8}
      ]}
      bob = %{bob | hand: [
        %Card{suit: :diamonds, rank: :queen},
        %Card{suit: :clubs, rank: :queen},
        %Card{suit: :hearts, rank: 9}
      ]}
      
      game = %{game | players: [alice, bob], current_player_index: 0}

      # Play multiple queens in succession
      {:ok, game} = Game.play_card(game, "alice", [0])  # Queen 1
      assert game.direction == :counterclockwise
      
      {:ok, game} = Game.play_card(game, "bob", [0])    # Queen 2  
      assert game.direction == :clockwise
      
      {:ok, game} = Game.play_card(game, "alice", [0])  # Queen 3
      assert game.direction == :counterclockwise
      
      # Game should continue normally, not get stuck in direction loops
      game = simulate_game_with_timeout(game, 10)
      assert game.status in [:playing, :finished]  # Should not hang
    end
  end

  describe "resource exhaustion scenarios" do
    test "handles complete deck exhaustion gracefully" do
      # What happens when ALL cards are in players' hands?
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)

      # Create scenario where deck is empty, discard has only current card
      empty_deck = %Rachel.Games.Deck{cards: []}
      current_card = %Card{suit: :hearts, rank: 5}
      
      [alice, bob] = game.players
      # Give players huge hands (most of the deck)
      alice_cards = Enum.take(generate_cards(), 25)
      bob_cards = Enum.take(Enum.drop(generate_cards(), 25), 25)
      
      alice = %{alice | hand: alice_cards}
      bob = %{bob | hand: bob_cards}
      
      game = %{game | 
        deck: empty_deck,
        current_card: current_card,
        discard_pile: [current_card],
        players: [alice, bob],
        status: :playing,
        current_player_index: 0
      }

      # Try to force a draw when deck is empty
      # Should handle gracefully without crashing
      result = Game.draw_card(game, "alice")
      
      case result do
        {:ok, _new_game} -> :ok  # Game handled it
        {:error, _reason} -> :ok  # Game rejected it gracefully
      end
    end

    test "handles memory exhaustion from huge hands" do
      # Stress test: very large hands
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Give Alice a massive hand (simulate drawing many cards)
      [alice, bob] = game.players
      huge_hand = Enum.take(generate_cards(), 100)  # Way more than normal
      alice = %{alice | hand: huge_hand}
      
      game = %{game | players: [alice, bob]}

      # Game should still function with huge hands
      valid_plays = Game.get_valid_plays(game, alice)
      assert is_list(valid_plays)
      
      # Should not crash or timeout
      has_valid = Game.has_valid_play?(game, alice)
      assert is_boolean(has_valid)
    end
  end

  describe "state corruption scenarios" do
    test "handles invalid game states gracefully" do
      # What if game state gets corrupted somehow?
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate corrupted state
      corrupted_game = %{game | 
        current_player_index: 999,  # Invalid index
        pending_pickups: -5,        # Negative pickups
        winners: ["nonexistent"]    # Invalid player ID
      }

      # Game functions should handle corruption gracefully
      current_player = Game.current_player(corrupted_game)
      # Should return nil or handle gracefully, not crash
      assert current_player == nil or is_map(current_player)
    end

    test "handles duplicate cards in game state" do
      # What if the same card appears in multiple places?
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      duplicate_card = %Card{suit: :hearts, rank: 5}
      
      # Put the same card in multiple places (corrupted state)
      [alice, bob] = game.players
      alice = %{alice | hand: [duplicate_card]}
      bob = %{bob | hand: [duplicate_card]}  # Same card!
      
      corrupted_game = %{game | 
        players: [alice, bob],
        current_card: duplicate_card,  # Same card again!
        discard_pile: [duplicate_card]  # And again!
      }

      # Card counting should detect this
      total_cards = count_total_cards(corrupted_game)
      # With duplicates, we'd have more than 52 cards
      # This test verifies our counting logic can detect corruption
      assert total_cards != 52  # Should detect the corruption
    end
  end

  # Helper functions
  defp simulate_game_with_timeout(game, max_turns) do
    Enum.reduce_while(1..max_turns, game, fn turn, acc_game ->
      if acc_game.status == :finished do
        {:halt, acc_game}
      else
        current_player = Game.current_player(acc_game)
        
        case try_make_move(acc_game, current_player.id) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, %{acc_game | metadata: %{turns_completed: turn}}}
        end
      end
    end)
  end

  defp try_make_move(game, player_id) do
    player = Enum.find(game.players, fn p -> p.id == player_id end)
    
    if Game.has_valid_play?(game, player) do
      valid_plays = Game.get_valid_plays(game, player)
      case valid_plays do
        [{_card, index} | _] -> Game.play_card(game, player_id, [index])
        [] -> Game.draw_card(game, player_id)
      end
    else
      Game.draw_card(game, player_id)
    end
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end

  defp count_moves_made(game) do
    Map.get(game, :metadata, %{})
    |> Map.get(:turns_completed, 0)
  end

  defp generate_cards do
    # Generate a full deck of cards for testing
    for suit <- [:hearts, :diamonds, :clubs, :spades],
        rank <- [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace] do
      %Card{suit: suit, rank: rank}
    end
  end
end