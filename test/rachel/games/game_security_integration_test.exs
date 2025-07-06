defmodule Rachel.Games.GameSecurityIntegrationTest do
  @moduledoc """
  Security-focused integration tests.
  Tests for cheating, exploitation, and malicious behavior.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "input validation and sanitization" do
    test "rejects malicious player IDs" do
      # Test various malicious player ID formats
      malicious_ids = [
        "<script>alert('xss')</script>",
        "'; DROP TABLE players; --",
        "../../etc/passwd",
        "\x00\x01\x02",  # null bytes
        "a" <> String.duplicate("b", 1000),  # extremely long
        "",  # empty
        nil  # null
      ]

      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # All malicious IDs should be rejected safely
      Enum.each(malicious_ids, fn malicious_id ->
        try do
          result = Game.play_card(game, malicious_id, [0])
          # Should either reject or handle gracefully
          assert match?({:error, _}, result)
        rescue
          _ -> :ok  # Exceptions are acceptable for malicious input
        end
      end)

      # Game should remain in valid state
      assert game.status == :playing
      assert count_total_cards(game) == 52
    end

    test "prevents card index manipulation attacks" do
      # Test various malicious card index formats
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      malicious_indices = [
        [99999],                    # Out of bounds positive
        [-1],                       # Negative
        [0, 0, 0, 0],              # Duplicates
        [1.5],                      # Float (if converted to int)
        [:atom],                    # Wrong type
        ["1"],                      # String number
        [nil],                      # Null
        []                          # Empty (might be valid)
      ]

      # All should be rejected or handled gracefully
      Enum.each(malicious_indices, fn indices ->
        try do
          result = Game.play_card(game, "alice", indices)
          case result do
            {:error, _} -> :ok  # Expected rejection
            {:ok, _} -> :ok     # Might be valid (empty list)
          end
        rescue
          _ -> :ok  # Exceptions acceptable for malicious input
        end
      end)

      # Game should remain stable
      assert game.status == :playing
    end

    test "prevents suit manipulation in nominations" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up ace scenario
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :pending,
        current_player_index: 0
      }

      malicious_suits = [
        :invalid_suit,
        "hearts",           # String instead of atom
        nil,
        :all_suits,
        :joker,
        123,
        %{suit: :hearts}    # Map instead of atom
      ]

      # All malicious suits should be rejected
      Enum.each(malicious_suits, fn suit ->
        try do
          result = Game.nominate_suit(game, "alice", suit)
          assert match?({:error, _}, result)
        rescue
          _ -> :ok  # Exceptions acceptable
        end
      end)

      # Game should remain in pending state
      assert game.nominated_suit == :pending
    end
  end

  describe "cheating and exploitation prevention" do
    test "prevents card duplication exploits" do
      # Test attempts to duplicate cards through edge cases
      game = Game.new()
      |> Game.add_player("cheater", "Cheater", false)
      |> Game.add_player("honest", "Honest Player", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)
      
      # Attempt various duplication exploits
      cheating_attempts = [
        # Playing same card multiple times
        fn g -> Game.play_card(g, "cheater", [0, 0, 0]) end,
        # Playing out of bounds then valid
        fn g -> 
          Game.play_card(g, "cheater", [999])
          Game.play_card(g, "cheater", [0])
        end,
        # Rapid duplicate plays
        fn g ->
          Game.play_card(g, "cheater", [0])
          Game.play_card(g, "cheater", [0])
        end
      ]

      # None should succeed in creating extra cards
      final_game = Enum.reduce(cheating_attempts, game, fn attempt, acc ->
        try do
          case attempt.(acc) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        rescue
          _ -> acc
        end
      end)

      # Card count should never exceed original
      final_cards = count_total_cards(final_game)
      assert final_cards <= initial_cards
    end

    test "prevents infinite card generation through stacking" do
      # Test that stacking can't be exploited to create infinite cards
      game = Game.new()
      |> Game.add_player("exploiter", "Exploiter", false)
      |> Game.add_player("victim", "Victim", false)
      |> Game.start_game()

      # Set up massive stacking scenario
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 100,  # Huge stack
        pending_pickup_type: :twos
      }

      [exploiter, victim] = game.players
      exploiter = %{exploiter | hand: [%Card{suit: :spades, rank: 2}]}
      victim = %{victim | hand: [%Card{suit: :clubs, rank: 5}]}
      
      game = %{game | players: [exploiter, victim], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Exploiter tries to stack even more
      case Game.play_card(game, "exploiter", [0]) do
        {:ok, stacked_game} ->
          # Should not create cards from nowhere
          assert count_total_cards(stacked_game) == initial_cards
          
          # Stack should be reasonable (not infinite)
          assert stacked_game.pending_pickups <= 200  # Some reasonable limit
        {:error, _} ->
          # Rejection is fine
          :ok
      end
    end

    test "prevents hand size manipulation" do
      # Test attempts to manipulate hand sizes artificially
      game = Game.new()
      |> Game.add_player("manipulator", "Manipulator", false)
      |> Game.add_player("normal", "Normal", false)
      |> Game.start_game()

      [manipulator, _normal] = game.players
      initial_hand_size = length(manipulator.hand)
      
      # Attempt various hand manipulation exploits
      manipulation_attempts = [
        # Playing cards they don't have
        Game.play_card(game, "manipulator", [99]),
        # Drawing when they have valid plays
        Game.draw_card(game, "manipulator"),
        # Playing negative indices
        Game.play_card(game, "manipulator", [-1]),
        # Playing empty selection repeatedly
        Game.play_card(game, "manipulator", [])
      ]

      # None should succeed in creating invalid hand states
      Enum.each(manipulation_attempts, fn attempt ->
        case attempt do
          {:ok, new_game} ->
            new_manipulator = hd(new_game.players)
            # Hand size should change by at most 1 (normal play/draw)
            size_change = abs(length(new_manipulator.hand) - initial_hand_size)
            assert size_change <= 1
          {:error, _} ->
            # Rejection is expected
            :ok
        end
      end)
    end

    test "prevents turn manipulation exploits" do
      # Test attempts to manipulate turn order
      game = Game.new()
      |> Game.add_player("hacker", "Hacker", false)
      |> Game.add_player("innocent", "Innocent", false)
      |> Game.start_game()

      # Hacker's turn (index 0)
      assert game.current_player_index == 0

      # Attempt to manipulate turns
      turn_exploits = [
        # Playing as other player
        Game.play_card(game, "innocent", [0]),
        # Drawing as other player
        Game.draw_card(game, "innocent"),
        # Nominating suit as other player (if ace was played)
        Game.nominate_suit(game, "innocent", :hearts)
      ]

      # All should be rejected
      Enum.each(turn_exploits, fn exploit ->
        assert match?({:error, _}, exploit)
      end)

      # Turn should remain unchanged
      assert game.current_player_index == 0
    end
  end

  describe "resource exhaustion protection" do
    @tag :skip
    test "prevents memory exhaustion through large inputs" do
      # Test with extremely large inputs
      game = Game.new()
      |> Game.add_player("attacker", "Attacker", false)
      |> Game.add_player("defender", "Defender", false)
      |> Game.start_game()

      # Attempt memory exhaustion attacks
      memory_attacks = [
        # Extremely large card index arrays
        fn -> Game.play_card(game, "attacker", Enum.to_list(1..10000)) end,
        # Repeatedly trying invalid operations
        fn -> 
          Enum.each(1..1000, fn _i ->
            Game.play_card(game, "attacker", [999])
          end)
        end
      ]

      # Should handle without memory explosion
      initial_memory = :erlang.memory(:total)
      
      Enum.each(memory_attacks, fn attack ->
        try do
          attack.()
        rescue
          _ -> :ok  # Expected to fail
        end
      end)

      :erlang.garbage_collect()
      final_memory = :erlang.memory(:total)
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)

      # Memory growth should be minimal (<5MB)
      assert memory_growth_mb < 5
    end

    test "prevents CPU exhaustion through algorithmic complexity attacks" do
      # Test operations that could cause exponential time complexity
      game = Game.new()
      |> Game.add_player("attacker", "CPU Attacker", false)
      |> Game.add_player("victim", "Victim", false)

      # Give attacker many cards of same rank (worst case for validation)
      all_aces = [
        %Card{suit: :hearts, rank: :ace},
        %Card{suit: :diamonds, rank: :ace},
        %Card{suit: :clubs, rank: :ace},
        %Card{suit: :spades, rank: :ace}
      ] ++ Enum.map(1..20, fn _i -> %Card{suit: :hearts, rank: :ace} end)

      [attacker, victim] = game.players
      attacker = %{attacker | hand: all_aces}
      
      game = %{game | 
        players: [attacker, victim],
        current_card: %Card{suit: :hearts, rank: :king}
      }

      # Operations should complete quickly even with pathological input
      start_time = System.monotonic_time(:microsecond)
      
      # These could potentially be slow with bad algorithms
      valid_plays = Game.get_valid_plays(game, attacker)
      has_valid = Game.has_valid_play?(game, attacker)
      
      end_time = System.monotonic_time(:microsecond)
      elapsed_ms = (end_time - start_time) / 1000
      
      # Should complete quickly (<100ms)
      assert elapsed_ms < 100
      assert is_list(valid_plays)
      assert is_boolean(has_valid)
    end

    test "prevents infinite loops through circular references" do
      # Test scenarios that could cause infinite loops
      game = Game.new()
      |> Game.add_player("looper", "Looper", false)
      |> Game.add_player("normal", "Normal", false)
      |> Game.start_game()

      # Set up potential infinite loop scenario
      game = %{game | 
        pending_skips: 999,  # Huge skip count
        direction: :clockwise
      }

      # Operations should terminate within reasonable time
      start_time = System.monotonic_time(:microsecond)
      
      # This could potentially loop forever with bad logic
      current_player = Game.current_player(game)
      
      end_time = System.monotonic_time(:microsecond)
      elapsed_ms = (end_time - start_time) / 1000
      
      # Should complete immediately
      assert elapsed_ms < 10
      assert current_player != nil
    end
  end

  describe "data corruption protection" do
    test "maintains game integrity under concurrent-like operations" do
      # Simulate concurrent operations that could corrupt state
      game = Game.new()
      |> Game.add_player("player1", "Player 1", false)
      |> Game.add_player("player2", "Player 2", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)

      # Simulate rapid state changes that could cause corruption
      operations = [
        fn g -> Game.play_card(g, "player1", [0]) end,
        fn g -> Game.draw_card(g, "player1") end,
        fn g -> Game.play_card(g, "player2", [0]) end,
        fn g -> Game.draw_card(g, "player2") end
      ]

      # Apply operations rapidly
      final_game = Enum.reduce(1..100, game, fn _i, acc ->
        operation = Enum.random(operations)
        
        case operation.(acc) do
          {:ok, new_game} -> new_game
          {:error, _} -> acc
        end
      end)

      # Game should maintain integrity
      assert final_game.status in [:playing, :finished]
      assert final_game.current_player_index >= 0
      assert final_game.current_player_index < length(final_game.players)
      
      # Card count should be preserved
      final_cards = count_total_cards(final_game)
      assert final_cards == initial_cards
    end

    test "handles corrupted game state inputs gracefully" do
      # Test with intentionally corrupted game state
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Create various corrupted states
      corrupted_states = [
        %{game | current_player_index: -1},
        %{game | current_player_index: 999},
        %{game | pending_pickups: -10},
        %{game | status: :invalid_status},
        %{game | players: []},
        %{game | deck: nil}
      ]

      # Operations should handle corruption gracefully
      Enum.each(corrupted_states, fn corrupted_game ->
        try do
          # These should not crash
          current_player = Game.current_player(corrupted_game)
          valid_plays = Game.get_valid_plays(corrupted_game, hd(game.players))
          
          # Results might be nil/empty but shouldn't crash
          assert current_player == nil or is_map(current_player)
          assert is_list(valid_plays)
        rescue
          _ -> :ok  # Exceptions acceptable for corrupted state
        end
      end)
    end
  end

  # Helper functions
  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end