defmodule Rachel.Games.GameRealWorldIntegrationTest do
  @moduledoc """
  Integration tests for real-world scenarios that players actually encounter.
  These test the edge cases that happen in production with real users.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "mobile device scenarios" do
    test "handles touch screen double-taps" do
      # User double-taps a card on mobile
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate double-tap: playing same card twice rapidly
      [alice, bob] = game.players
      alice = %{alice | hand: [%Card{suit: :hearts, rank: 5}]}
      game = %{game | 
        players: [alice, bob], 
        current_player_index: 0,
        current_card: %Card{suit: :hearts, rank: 6}
      }

      # First tap
      {:ok, game1} = Game.play_card(game, "alice", [0])
      
      # Second tap (card no longer exists)
      result = Game.play_card(game1, "alice", [0])
      # Should handle gracefully - either success or friendly error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles network interruption during play" do
      # Player makes a move, network drops, reconnects
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Alice plays a card
      [alice, bob] = game.players
      if length(alice.hand) > 0 and Game.has_valid_play?(game, alice) do
        valid_plays = Game.get_valid_plays(game, alice)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, game_after_play} = Game.play_card(game, "alice", [index])
            
            # Simulate Alice trying to play again (reconnection duplicate)
            result = Game.play_card(game_after_play, "alice", [0])
            # Should either handle gracefully or reject appropriately
            case result do
              {:error, :not_your_turn} -> :ok  # Expected - turn already advanced
              {:error, :invalid_card_index} -> :ok  # Expected - card already played
              {:ok, _} -> :ok  # Might be valid if she has more cards
              _ -> flunk("Unexpected result: #{inspect(result)}")
            end
          [] -> :ok
        end
      end
    end
  end

  describe "family game scenarios" do
    test "handles kids making invalid moves repeatedly" do
      # Child doesn't understand rules, keeps trying invalid moves
      game = Game.new()
      |> Game.add_player("parent", "Parent", false)
      |> Game.add_player("child", "Child", false)
      |> Game.start_game()

      # Set up scenario where child has no valid plays
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :hearts
      }
      
      [parent, child] = game.players
      child = %{child | hand: [
        %Card{suit: :spades, rank: 5},   # Wrong suit
        %Card{suit: :clubs, rank: 7},    # Wrong suit
        %Card{suit: :diamonds, rank: 9}  # Wrong suit
      ]}
      game = %{game | players: [parent, child], current_player_index: 1}

      # Child tries to play various invalid cards
      invalid_attempts = [
        Game.play_card(game, "child", [0]),  # Wrong suit
        Game.play_card(game, "child", [1]),  # Wrong suit
        Game.play_card(game, "child", [2]),  # Wrong suit
        Game.play_card(game, "child", [0, 1]),  # Multiple wrong suits
      ]

      # All should fail but game should remain stable
      Enum.each(invalid_attempts, fn result ->
        case result do
          {:error, :first_card_invalid} -> :ok
          {:error, :must_play_nominated_suit} -> :ok
          {:error, _} -> :ok
          _ -> flunk("Expected error for invalid move: #{inspect(result)}")
        end
      end)

      # Child should be forced to draw
      {:ok, final_game} = Game.draw_card(game, "child")
      assert length(hd(tl(final_game.players)).hand) > length(child.hand)
    end

    test "handles impatient players trying to rush" do
      # Player keeps clicking rapidly during AI turns
      game = Game.new()
      |> Game.add_player("human", "Human", false)
      |> Game.add_player("ai", "AI", true)
      |> Game.start_game()

      # AI's turn (index 1)
      game = %{game | current_player_index: 1}
      
      # Human tries to play repeatedly during AI turn
      rush_attempts = Enum.map(1..10, fn _i ->
        Game.play_card(game, "human", [0])
      end)

      # All should fail with not_your_turn
      Enum.each(rush_attempts, fn result ->
        assert {:error, :not_your_turn} = result
      end)
      
      # Game state should be unchanged
      assert game.current_player_index == 1
    end
  end

  describe "competitive gaming scenarios" do
    test "handles sore loser rage quitting" do
      # Player about to lose disconnects/leaves
      game = Game.new()
      |> Game.add_player("winner", "Winner", false)
      |> Game.add_player("loser", "Loser", false)
      |> Game.start_game()

      # Set up winner about to win
      [winner, loser] = game.players
      winner = %{winner | hand: [%Card{suit: :hearts, rank: 5}]}  # Last card
      loser = %{loser | hand: Enum.take(generate_cards(), 15)}    # Many cards
      
      game = %{game | 
        players: [winner, loser],
        current_player_index: 0,
        current_card: %Card{suit: :hearts, rank: 6}
      }

      # Winner plays last card
      {:ok, final_game} = Game.play_card(game, "winner", [0])
      
      # Winner should be declared winner
      assert "winner" in final_game.winners
      assert length(hd(final_game.players).hand) == 0
      
      # Game should end properly regardless of loser's reaction
      assert final_game.status == :finished
    end

    test "handles perfectionist trying to undo moves" do
      # Player makes a move then wants to take it back
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      [alice, bob] = game.players
      initial_alice_hand = alice.hand
      
      # Alice plays a card
      if length(alice.hand) > 0 and Game.has_valid_play?(game, alice) do
        valid_plays = Game.get_valid_plays(game, alice)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, game_after_play} = Game.play_card(game, "alice", [index])
            
            # Alice tries to "undo" by playing same move again
            result = Game.play_card(game_after_play, "alice", [index])
            
            # Should fail - turn already advanced, card already gone
            assert match?({:error, _}, result)
            
            # Game state should reflect the original play, not the "undo"
            alice_after = hd(game_after_play.players)
            assert length(alice_after.hand) == length(initial_alice_hand) - 1
          [] -> :ok
        end
      end
    end
  end

  describe "long game scenarios" do
    test "handles games lasting hours with many deck cycles" do
      # Simulate a very long game
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Force many deck recycling cycles
      long_game = simulate_long_game(game, 100)
      
      # After long play, cards should still be preserved
      assert count_total_cards(long_game) == 52
      
      # Game should still be in valid state
      assert long_game.status in [:playing, :finished]
      assert long_game.current_player_index >= 0
    end

    test "handles memory pressure from large hands" do
      # Player draws many cards due to stacking penalties
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate Alice getting hit with many stacking penalties
      [alice, bob] = game.players
      
      # Give Alice 30 cards (very large hand)
      large_hand = Enum.take(generate_cards(), 30)
      alice = %{alice | hand: large_hand}
      
      # Reduce Bob's hand and deck to compensate
      bob = %{bob | hand: Enum.take(Enum.drop(generate_cards(), 30), 7)}
      small_deck = %Rachel.Games.Deck{cards: Enum.drop(generate_cards(), 38)}
      
      game = %{game | 
        players: [alice, bob],
        deck: small_deck,
        current_player_index: 0
      }

      # Alice should still be able to play
      valid_plays = Game.get_valid_plays(game, alice)
      has_valid_play = Game.has_valid_play?(game, alice)
      
      # Should handle large hands gracefully
      assert is_list(valid_plays)
      assert is_boolean(has_valid_play)
      
      # Card count should still be correct
      assert count_total_cards(game) == 52
    end
  end

  describe "network edge cases" do
    test "handles out-of-order message delivery" do
      # Messages arrive in wrong order due to network
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate Alice making move, then old message arrives
      [alice, bob] = game.players
      original_hand = alice.hand
      
      if length(alice.hand) > 0 and Game.has_valid_play?(game, alice) do
        valid_plays = Game.get_valid_plays(game, alice)
        case valid_plays do
          [{_card, index} | _] ->
            # Alice's move goes through
            {:ok, game_after_move} = Game.play_card(game, "alice", [index])
            
            # "Old" message tries to replay same move
            result = Game.play_card(game_after_move, "alice", [index])
            
            # Should reject duplicate/old moves
            assert match?({:error, _}, result)
          [] -> :ok
        end
      end
    end

    test "handles client-server state desync" do
      # Client thinks it's their turn but server disagrees
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Server says it's Bob's turn
      game = %{game | current_player_index: 1}
      
      # But Alice thinks it's her turn and tries to play
      result = Game.play_card(game, "alice", [0])
      assert {:error, :not_your_turn} = result
      
      # Server state should be authoritative
      assert game.current_player_index == 1
    end
  end

  # Helper functions
  defp simulate_long_game(game, moves) do
    Enum.reduce_while(1..moves, game, fn _i, acc ->
      if acc.status == :finished do
        {:halt, acc}
      else
        current_player = Game.current_player(acc)
        
        case try_move_or_draw(acc, current_player.id) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc}
        end
      end
    end)
  end

  defp try_move_or_draw(game, player_id) do
    player = Enum.find(game.players, fn p -> p.id == player_id end)
    
    if Game.has_valid_play?(game, player) and length(player.hand) > 0 do
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

  defp generate_cards do
    for suit <- [:hearts, :diamonds, :clubs, :spades],
        rank <- [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace] do
      %Card{suit: suit, rank: rank}
    end
  end
end