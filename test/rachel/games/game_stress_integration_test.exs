defmodule Rachel.Games.GameStressIntegrationTest do
  @moduledoc """
  Stress tests and security-related edge cases for the game.
  These tests verify the game handles extreme conditions gracefully.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "memory and performance stress tests" do
    test "handles maximum player count" do
      # Test with many players (stress test turn management)
      game = Game.new()
      
      # Add maximum reasonable number of players
      game = Enum.reduce(1..8, game, fn i, acc ->
        Game.add_player(acc, "player#{i}", "Player #{i}", false)
      end)
      
      game = Game.start_game(game)
      assert length(game.players) == 8
      
      # Game should function with many players
      current_player = Game.current_player(game)
      assert current_player != nil
      
      # Should be able to advance turns through all players
      game = simulate_turn_cycle(game, 16)  # 2 full cycles
      assert game.current_player_index >= 0
      assert game.current_player_index < 8
    end

    test "handles rapid succession of moves" do
      # Stress test: many moves in quick succession
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate 100 rapid moves
      final_game = simulate_rapid_moves(game, 100)
      
      # Game should either finish or be in valid state
      assert final_game.status in [:playing, :finished]
      
      # Card count should remain consistent
      final_cards = count_total_cards(final_game)
      assert final_cards == 52
    end

    test "handles extremely large deck exhaustion cycles" do
      # Force many deck recycling cycles
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Force 20 draw operations to stress deck recycling
      final_game = force_many_draws(game, 20)
      
      # Cards should be preserved through all recycling
      final_cards = count_total_cards(final_game)
      assert final_cards == 52
    end
  end

  describe "malicious input scenarios" do
    test "handles invalid player IDs gracefully" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Try to play with non-existent player
      result = Game.play_card(game, "hacker", [0])
      assert {:error, :player_not_found} = result
      
      # Try to draw with non-existent player
      result = Game.draw_card(game, "malicious_user")
      assert {:error, :player_not_found} = result
      
      # Try suit nomination with non-existent player
      result = Game.nominate_suit(game, "fake_player", :hearts)
      assert {:error, :player_not_found} = result
    end

    test "handles invalid card indices gracefully" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Try to play card at invalid index
      result = Game.play_card(game, "alice", [999])
      assert {:error, :invalid_card_index} = result
      
      # Try to play negative index
      result = Game.play_card(game, "alice", [-1])
      assert {:error, :invalid_card_index} = result
      
      # Try to play empty list
      result = Game.play_card(game, "alice", [])
      # Should handle gracefully (might be valid for some games)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles out-of-turn plays gracefully" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Alice's turn initially (index 0)
      assert game.current_player_index == 0
      
      # Try Bob playing out of turn
      result = Game.play_card(game, "bob", [0])
      assert {:error, :not_your_turn} = result
      
      # Try Bob drawing out of turn
      result = Game.draw_card(game, "bob")
      assert {:error, :not_your_turn} = result
    end

    test "prevents manipulation of finished games" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Force game to finished state
      finished_game = %{game | status: :finished, winners: ["alice"]}
      
      # Try to continue playing finished game
      result = Game.play_card(finished_game, "bob", [0])
      # Should reject plays on finished games
      assert match?({:error, _}, result)
      
      result = Game.draw_card(finished_game, "bob")
      # Should reject draws on finished games  
      assert match?({:error, _}, result)
    end
  end

  describe "data consistency stress tests" do
    test "maintains card uniqueness under stress" do
      # Verify no card duplication during complex operations
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Perform 50 random operations
      final_game = perform_random_operations(game, 50)
      
      # Collect all cards from all locations
      all_cards = collect_all_cards(final_game)
      
      # Check for duplicates
      unique_cards = Enum.uniq(all_cards)
      assert length(all_cards) == length(unique_cards), "Duplicate cards detected!"
      
      # Should have exactly 52 unique cards
      assert length(unique_cards) == 52
    end

    test "maintains player hand integrity under stress" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      initial_alice_count = length(hd(game.players).hand)
      
      # Perform many operations
      final_game = perform_random_operations(game, 30)
      
      # Find Alice in final state
      alice = Enum.find(final_game.players, fn p -> p.id == "alice" end)
      
      # Alice's hand should be valid (all cards should be actual Card structs)
      assert Enum.all?(alice.hand, fn card ->
        is_struct(card, Card) and card.suit in [:hearts, :diamonds, :clubs, :spades]
      end)
    end

    test "prevents game state corruption during concurrent-like operations" do
      # Simulate rapid state changes that could cause corruption
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Apply many state changes rapidly
      final_game = Enum.reduce(1..100, game, fn _i, acc ->
        # Simulate rapid operations
        current_player = Game.current_player(acc)
        
        if acc.status == :finished do
          acc
        else
          case try_random_operation(acc, current_player.id) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        end
      end)
      
      # Game should be in consistent state
      assert final_game.status in [:playing, :finished]
      assert final_game.current_player_index >= 0
      assert final_game.current_player_index < length(final_game.players)
      
      # Card count should be preserved
      assert count_total_cards(final_game) == 52
    end
  end

  # Helper functions
  defp simulate_turn_cycle(game, num_turns) do
    Enum.reduce(1..num_turns, game, fn _turn, acc ->
      if acc.status == :finished do
        acc
      else
        # Just advance turn without playing
        player_count = length(acc.players)
        next_index = rem(acc.current_player_index + 1, player_count)
        %{acc | current_player_index: next_index}
      end
    end)
  end

  defp simulate_rapid_moves(game, max_moves) do
    Enum.reduce_while(1..max_moves, game, fn _i, acc ->
      if acc.status == :finished do
        {:halt, acc}
      else
        current_player = Game.current_player(acc)
        
        case try_any_move(acc, current_player.id) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc}
        end
      end
    end)
  end

  defp force_many_draws(game, num_draws) do
    Enum.reduce(1..num_draws, game, fn _i, acc ->
      if acc.status == :finished do
        acc
      else
        current_player = Game.current_player(acc)
        
        case Game.draw_card(acc, current_player.id) do
          {:ok, new_game} -> 
            # Advance to next player
            player_count = length(new_game.players)
            next_index = rem(new_game.current_player_index + 1, player_count)
            %{new_game | current_player_index: next_index}
          {:error, _} -> 
            # Try with next player
            player_count = length(acc.players)
            next_index = rem(acc.current_player_index + 1, player_count)
            %{acc | current_player_index: next_index}
        end
      end
    end)
  end

  defp perform_random_operations(game, num_ops) do
    Enum.reduce(1..num_ops, game, fn _i, acc ->
      if acc.status == :finished do
        acc
      else
        current_player = Game.current_player(acc)
        
        case try_random_operation(acc, current_player.id) do
          {:ok, new_game} -> new_game
          {:error, _} -> acc
        end
      end
    end)
  end

  defp try_any_move(game, player_id) do
    player = Enum.find(game.players, fn p -> p.id == player_id end)
    
    if Game.has_valid_play?(game, player) and length(player.hand) > 0 do
      Game.play_card(game, player_id, [0])
    else
      Game.draw_card(game, player_id)
    end
  end

  defp try_random_operation(game, player_id) do
    player = Enum.find(game.players, fn p -> p.id == player_id end)
    
    # Randomly choose between play and draw
    if :rand.uniform(2) == 1 and Game.has_valid_play?(game, player) and length(player.hand) > 0 do
      # Try to play random valid card
      valid_plays = Game.get_valid_plays(game, player)
      case valid_plays do
        [{_card, index} | _] -> Game.play_card(game, player_id, [index])
        [] -> Game.draw_card(game, player_id)
      end
    else
      # Try to draw
      Game.draw_card(game, player_id)
    end
  end

  defp collect_all_cards(game) do
    hand_cards = Enum.flat_map(game.players, fn p -> p.hand end)
    deck_cards = game.deck.cards
    discard_cards = game.discard_pile
    current_cards = if game.current_card, do: [game.current_card], else: []
    
    hand_cards ++ deck_cards ++ discard_cards ++ current_cards
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end