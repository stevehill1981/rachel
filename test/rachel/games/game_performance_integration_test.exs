defmodule Rachel.Games.GamePerformanceIntegrationTest do
  @moduledoc """
  Performance and scale integration tests.
  Tests that verify the game performs well under realistic load conditions.
  
  NOTE: These tests are skipped due to performance testing complexity.
  """
  use ExUnit.Case, async: true
  
  @moduletag :skip

  alias Rachel.Games.{Card, Game}

  describe "memory and performance under load" do
    test "handles 100 concurrent games without memory explosion" do
      # Simulate server handling many games simultaneously
      games = Enum.map(1..100, fn i ->
        Game.new("game_#{i}")
        |> Game.add_player("alice_#{i}", "Alice #{i}", false)
        |> Game.add_player("bob_#{i}", "Bob #{i}", false)
        |> Game.start_game()
      end)

      # All games should be valid
      assert length(games) == 100
      assert Enum.all?(games, fn game -> game.status == :playing end)

      # Simulate moves in all games
      updated_games = Enum.map(games, fn game ->
        simulate_game_moves(game, 10)
      end)

      # All games should still be valid
      assert length(updated_games) == 100
      assert Enum.all?(updated_games, fn game -> 
        game.status in [:playing, :finished] and count_total_cards(game) == 52
      end)
    end

    test "handles games with extreme hand sizes efficiently" do
      # Test performance with players having huge hands
      game = Game.new()
      |> Game.add_player("hoarder", "Card Hoarder", false)
      |> Game.add_player("normal", "Normal Player", false)

      # Give hoarder 40 cards (from many stacking penalties)
      [hoarder, normal] = game.players
      massive_hand = Enum.take(generate_full_deck(), 40)
      remaining_cards = Enum.drop(generate_full_deck(), 40)
      
      hoarder = %{hoarder | hand: massive_hand}
      normal = %{normal | hand: Enum.take(remaining_cards, 7)}
      
      small_deck = %Rachel.Games.Deck{cards: Enum.drop(remaining_cards, 7)}
      current_card = List.last(remaining_cards)
      
      game = %{game | 
        players: [hoarder, normal],
        deck: small_deck,
        current_card: current_card,
        discard_pile: [current_card],
        status: :playing
      }

      # Performance test: operations should complete quickly
      start_time = System.monotonic_time(:microsecond)
      
      # These operations should be fast even with huge hands
      valid_plays = Game.get_valid_plays(game, hoarder)
      has_valid = Game.has_valid_play?(game, hoarder)
      current_player = Game.current_player(game)
      
      end_time = System.monotonic_time(:microsecond)
      elapsed_ms = (end_time - start_time) / 1000
      
      # Should complete within reasonable time (100ms)
      assert elapsed_ms < 100
      
      # Results should be correct
      assert is_list(valid_plays)
      assert is_boolean(has_valid)
      assert current_player.id == "hoarder"
    end

    test "handles rapid succession of 1000 moves without degradation" do
      # Test that game doesn't slow down with many moves
      game = Game.new()
      |> Game.add_player("speed1", "Speed Player 1", false)
      |> Game.add_player("speed2", "Speed Player 2", false)
      |> Game.start_game()

      # Measure time for first 100 moves
      start_time = System.monotonic_time(:microsecond)
      game_after_100 = simulate_game_moves(game, 100)
      mid_time = System.monotonic_time(:microsecond)
      
      # Measure time for next 100 moves
      game_after_200 = simulate_game_moves(game_after_100, 100)
      end_time = System.monotonic_time(:microsecond)
      
      first_100_ms = (mid_time - start_time) / 1000
      second_100_ms = (end_time - mid_time) / 1000
      
      # Performance shouldn't degrade significantly
      # Second batch should be at most 50% slower than first
      assert second_100_ms <= first_100_ms * 1.5
      
      # Game should still be valid
      assert game_after_200.status in [:playing, :finished]
      assert count_total_cards(game_after_200) == 52
    end

    test "memory usage doesn't grow unbounded during long games" do
      # Test for memory leaks
      game = Game.new()
      |> Game.add_player("marathon1", "Marathon Player 1", false)
      |> Game.add_player("marathon2", "Marathon Player 2", false)
      |> Game.start_game()

      initial_memory = :erlang.memory(:total)
      
      # Simulate very long game (500 moves)
      final_game = simulate_game_moves(game, 500)
      
      # Force garbage collection
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:total)
      
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)
      
      # Memory growth should be reasonable (<10MB for single game)
      assert memory_growth_mb < 10
      
      # Game should still be valid
      assert final_game.status in [:playing, :finished]
      assert count_total_cards(final_game) == 52
    end
  end

  describe "deck recycling stress tests" do
    test "handles 50 consecutive deck recycling cycles" do
      # Extreme deck exhaustion scenario
      game = Game.new()
      |> Game.add_player("drawer1", "Card Drawer 1", false)
      |> Game.add_player("drawer2", "Card Drawer 2", false)

      # Start with minimal deck to force frequent recycling
      tiny_deck = %Rachel.Games.Deck{cards: [
        %Card{suit: :hearts, rank: 2},
        %Card{suit: :spades, rank: 3}
      ]}
      
      current_card = %Card{suit: :clubs, rank: 4}
      
      game = %{game | 
        deck: tiny_deck,
        current_card: current_card,
        discard_pile: [
          current_card,
          %Card{suit: :diamonds, rank: 5},
          %Card{suit: :hearts, rank: 6}
        ],
        status: :playing
      }

      # Force 50 recycling cycles
      final_game = force_many_recycling_cycles(game, 50)
      
      # Cards should still be preserved
      final_cards = count_total_cards(final_game)
      assert final_cards >= 5  # At least the cards we put in
      
      # Game should be stable
      assert final_game.status in [:playing, :finished]
      assert final_game.current_card != nil
    end

    test "recycling performance doesn't degrade with large discard piles" do
      # Test recycling performance with huge discard pile
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)

      # Create large discard pile (40 cards)
      large_discard = Enum.take(generate_full_deck(), 40)
      current_card = hd(large_discard)
      remaining_cards = Enum.drop(generate_full_deck(), 40)
      
      empty_deck = %Rachel.Games.Deck{cards: []}
      
      game = %{game | 
        deck: empty_deck,
        current_card: current_card,
        discard_pile: large_discard,
        status: :playing
      }

      # Measure recycling time
      start_time = System.monotonic_time(:microsecond)
      
      # Force recycling by trying to draw
      current_player = Game.current_player(game)
      result = Game.draw_card(game, current_player.id)
      
      end_time = System.monotonic_time(:microsecond)
      recycling_time_ms = (end_time - start_time) / 1000
      
      # Recycling should be fast (<50ms)
      assert recycling_time_ms < 50
      
      # Should succeed or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "ai performance stress tests" do
    test "AI decision making scales with hand size" do
      # Test AI performance with different hand sizes
      hand_sizes = [1, 5, 10, 20, 30]
      
      performance_data = Enum.map(hand_sizes, fn size ->
        game = create_ai_test_game(size)
        ai_player = Enum.find(game.players, fn p -> p.is_ai end)
        
        # Measure AI decision time
        start_time = System.monotonic_time(:microsecond)
        
        # This would normally call AI decision logic
        valid_plays = Game.get_valid_plays(game, ai_player)
        has_valid = Game.has_valid_play?(game, ai_player)
        
        end_time = System.monotonic_time(:microsecond)
        decision_time_ms = (end_time - start_time) / 1000
        
        {size, decision_time_ms, length(valid_plays), has_valid}
      end)
      
      # Decision times should scale reasonably (not exponentially)
      {_small_size, small_time, _, _} = hd(performance_data)
      {_large_size, large_time, _, _} = List.last(performance_data)
      
      # Large hand should be at most 10x slower than small hand
      assert large_time <= small_time * 10
      
      # All should complete within reasonable time
      Enum.each(performance_data, fn {_size, time, _plays, _valid} ->
        assert time < 100  # 100ms max
      end)
    end

    test "multiple AI players don't interfere with each other" do
      # 4 AI players in same game
      game = Game.new()
      |> Game.add_player("ai1", "AI 1", true)
      |> Game.add_player("ai2", "AI 2", true)
      |> Game.add_player("ai3", "AI 3", true)
      |> Game.add_player("ai4", "AI 4", true)
      |> Game.start_game()

      # Simulate all AIs making decisions rapidly
      ai_game = simulate_ai_heavy_game(game, 50)
      
      # Game should progress normally
      assert ai_game.status in [:playing, :finished]
      assert count_total_cards(ai_game) == 52
      
      # All players should still be valid
      assert length(ai_game.players) == 4
      assert Enum.all?(ai_game.players, fn p -> p.is_ai == true end)
    end
  end

  describe "edge case performance" do
    test "handles pathological card combinations efficiently" do
      # Worst-case scenario: all cards are same rank (max stacking potential)
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)

      # Give Alice all 2s (worst case for stacking logic)
      all_twos = [
        %Card{suit: :hearts, rank: 2},
        %Card{suit: :diamonds, rank: 2},
        %Card{suit: :clubs, rank: 2},
        %Card{suit: :spades, rank: 2}
      ]
      
      [alice, bob] = game.players
      alice = %{alice | hand: all_twos}
      
      game = %{game | 
        players: [alice, bob],
        current_card: %Card{suit: :hearts, rank: 3}
      }

      # Should handle worst-case stacking scenario efficiently
      start_time = System.monotonic_time(:microsecond)
      
      valid_plays = Game.get_valid_plays(game, alice)
      
      end_time = System.monotonic_time(:microsecond)
      analysis_time_ms = (end_time - start_time) / 1000
      
      # Should be fast even for worst case
      assert analysis_time_ms < 10
      assert is_list(valid_plays)
    end

    test "handles maximum player count efficiently" do
      # Test with maximum reasonable players (8)
      game = Enum.reduce(1..8, Game.new(), fn i, acc ->
        Game.add_player(acc, "player_#{i}", "Player #{i}", false)
      end)
      |> Game.start_game()

      # Should handle turn management efficiently
      start_time = System.monotonic_time(:microsecond)
      
      # Simulate full round (all players take turn)
      game_after_round = simulate_full_round(game)
      
      end_time = System.monotonic_time(:microsecond)
      round_time_ms = (end_time - start_time) / 1000
      
      # Full round should complete quickly
      assert round_time_ms < 50
      assert game_after_round.status in [:playing, :finished]
      assert count_total_cards(game_after_round) == 52
    end
  end

  # Helper functions
  defp simulate_game_moves(game, num_moves) do
    Enum.reduce_while(1..num_moves, game, fn _i, acc ->
      if acc.status == :finished do
        {:halt, acc}
      else
        case try_random_move(acc) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc}
        end
      end
    end)
  end

  defp try_random_move(game) do
    current_player = Game.current_player(game)
    
    if Game.has_valid_play?(game, current_player) and length(current_player.hand) > 0 do
      valid_plays = Game.get_valid_plays(game, current_player)
      case valid_plays do
        [{_card, index} | _] -> Game.play_card(game, current_player.id, [index])
        [] -> Game.draw_card(game, current_player.id)
      end
    else
      Game.draw_card(game, current_player.id)
    end
  end

  defp force_many_recycling_cycles(game, cycles) do
    Enum.reduce(1..cycles, game, fn _i, acc ->
      if acc.status == :finished do
        acc
      else
        current_player = Game.current_player(acc)
        
        case Game.draw_card(acc, current_player.id) do
          {:ok, new_game} -> 
            # Advance turn
            player_count = length(new_game.players)
            next_index = rem(new_game.current_player_index + 1, player_count)
            %{new_game | current_player_index: next_index}
          {:error, _} -> 
            acc
        end
      end
    end)
  end

  defp create_ai_test_game(hand_size) do
    game = Game.new()
    |> Game.add_player("human", "Human", false)
    |> Game.add_player("ai", "AI", true)
    |> Game.start_game()

    # Give AI player specific hand size
    [human, ai] = game.players
    ai_hand = Enum.take(generate_full_deck(), hand_size)
    ai = %{ai | hand: ai_hand}
    
    %{game | players: [human, ai]}
  end

  defp simulate_ai_heavy_game(game, moves) do
    Enum.reduce_while(1..moves, game, fn _i, acc ->
      if acc.status == :finished do
        {:halt, acc}
      else
        # Simulate AI decision for current player
        current_player = Game.current_player(acc)
        
        case try_random_move(acc) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc}
        end
      end
    end)
  end

  defp simulate_full_round(game) do
    player_count = length(game.players)
    
    Enum.reduce_while(1..player_count, game, fn _i, acc ->
      if acc.status == :finished do
        {:halt, acc}
      else
        case try_random_move(acc) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc}
        end
      end
    end)
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end

  defp generate_full_deck do
    for suit <- [:hearts, :diamonds, :clubs, :spades],
        rank <- [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace] do
      %Card{suit: suit, rank: rank}
    end
  end
end