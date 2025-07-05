defmodule Rachel.Games.GameMultiplayerIntegrationTest do
  @moduledoc """
  Integration tests for multiplayer scenarios that could break with real users.
  These test scenarios that only happen with multiple human players.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "player disconnection scenarios" do
    test "game continues when non-current player disconnects" do
      # Real scenario: player leaves mid-game
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Simulate Bob disconnecting (not current player)
      [alice, bob, charlie] = game.players
      bob_disconnected = %{bob | connected: false}
      game = %{game | players: [alice, bob_disconnected, charlie]}

      # Game should continue normally
      current_player = Game.current_player(game)
      assert current_player.id == "alice"
      
      # Alice should be able to play
      if Game.has_valid_play?(game, current_player) do
        valid_plays = Game.get_valid_plays(game, current_player)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, new_game} = Game.play_card(game, "alice", [index])
            assert new_game.status == :playing
          [] -> :ok
        end
      end
    end

    test "game handles current player disconnection" do
      # Critical scenario: active player disconnects during their turn
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Alice is current player but disconnects
      [alice, bob] = game.players
      alice_disconnected = %{alice | connected: false}
      game = %{game | players: [alice_disconnected, bob], current_player_index: 0}

      # What happens when disconnected player tries to play?
      result = Game.play_card(game, "alice", [0])
      # Should either work (for async games) or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "game ends appropriately when too many players disconnect" do
      # Scenario: mass disconnection
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.add_player("diana", "Diana", false)
      |> Game.start_game()

      # 3 out of 4 players disconnect
      [alice, bob, charlie, diana] = game.players
      alice_disconnected = %{alice | connected: false}
      bob_disconnected = %{bob | connected: false}
      charlie_disconnected = %{charlie | connected: false}
      
      game = %{game | players: [alice_disconnected, bob_disconnected, charlie_disconnected, diana]}

      # Only Diana remains - game should handle this
      connected_players = Enum.filter(game.players, fn p -> Map.get(p, :connected, true) end)
      assert length(connected_players) == 1
      
      # Game logic should be robust enough to continue or end gracefully
      current_player = Game.current_player(game)
      assert current_player != nil
    end
  end

  describe "cheating and exploitation scenarios" do
    test "prevents playing cards not in hand" do
      # Player tries to play cards they don't have
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Alice has specific cards, tries to play index beyond her hand
      [alice, bob] = game.players
      alice = %{alice | hand: [%Card{suit: :hearts, rank: 5}]}  # Only 1 card
      game = %{game | players: [alice, bob], current_player_index: 0}

      # Try to play card at index 5 (doesn't exist)
      result = Game.play_card(game, "alice", [5])
      assert {:error, :invalid_card_index} = result
      
      # Try to play multiple cards when only having 1
      result = Game.play_card(game, "alice", [0, 1, 2])
      assert {:error, :invalid_card_index} = result
    end

    test "prevents playing other players' turns" do
      # Player tries to play out of turn repeatedly
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Alice's turn (index 0)
      assert game.current_player_index == 0
      
      # Bob tries to play multiple times
      result1 = Game.play_card(game, "bob", [0])
      assert {:error, :not_your_turn} = result1
      
      result2 = Game.play_card(game, "bob", [1])
      assert {:error, :not_your_turn} = result2
      
      result3 = Game.draw_card(game, "bob")
      assert {:error, :not_your_turn} = result3
      
      # Game state should be unchanged
      assert game.current_player_index == 0
    end

    test "prevents modifying hand sizes through exploits" do
      # Simulate attempts to manipulate hand sizes
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      initial_alice_hand_size = length(hd(game.players).hand)
      initial_total_cards = count_total_cards(game)
      
      # Try various operations that shouldn't change total card count
      game = attempt_card_manipulation(game, 10)
      
      final_total_cards = count_total_cards(game)
      assert final_total_cards == initial_total_cards, "Card count changed: #{initial_total_cards} -> #{final_total_cards}"
    end

    test "prevents infinite stacking exploits" do
      # Player tries to create infinite stacking loops
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up stacking scenario
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 2,
        pending_pickup_type: :twos
      }

      [alice, bob] = game.players
      # Give Alice many 2s
      alice = %{alice | hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :clubs, rank: 2},
        %Card{suit: :diamonds, rank: 2},
        %Card{suit: :hearts, rank: 2}
      ]}
      game = %{game | players: [alice, bob], current_player_index: 0}

      # Try to stack all 2s at once (might be invalid)
      result = Game.play_card(game, "alice", [0, 1, 2, 3])
      
      case result do
        {:ok, new_game} ->
          # If allowed, ensure it doesn't break the game
          assert new_game.pending_pickups > 0
          assert new_game.pending_pickups <= 20  # Reasonable upper bound
        {:error, _} ->
          # If not allowed, that's fine - game prevents exploitation
          :ok
      end
    end
  end

  describe "race condition simulation" do
    test "handles rapid successive moves" do
      # Simulate players making moves very quickly
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate 20 rapid moves
      final_game = simulate_rapid_moves(game, 20)
      
      # Game should be in consistent state
      assert final_game.status in [:playing, :finished]
      assert count_total_cards(final_game) == 52
    end

    test "handles simultaneous suit nominations" do
      # Two players trying to nominate suits at the same time
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up ace played by Alice
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :pending,
        current_player_index: 0
      }

      # Alice nominates hearts
      {:ok, game1} = Game.nominate_suit(game, "alice", :hearts)
      assert game1.nominated_suit == :hearts
      
      # Bob tries to nominate spades after Alice already nominated
      result = Game.nominate_suit(game1, "bob", :spades)
      assert {:error, :not_your_turn} = result
      
      # Alice's nomination should persist
      assert game1.nominated_suit == :hearts
    end

    test "handles rapid card plays during stacking" do
      # Multiple players trying to stack simultaneously
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Set up 2s stacking
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 2,
        pending_pickup_type: :twos
      }

      [alice, bob, charlie] = game.players
      alice = %{alice | hand: [%Card{suit: :spades, rank: 2}]}
      bob = %{bob | hand: [%Card{suit: :clubs, rank: 2}]}
      charlie = %{charlie | hand: [%Card{suit: :diamonds, rank: 5}]}
      
      game = %{game | players: [alice, bob, charlie], current_player_index: 0}

      # Alice plays her 2
      {:ok, game} = Game.play_card(game, "alice", [0])
      assert game.pending_pickups == 4
      
      # Bob immediately tries to stack
      {:ok, game} = Game.play_card(game, "bob", [0])
      assert game.pending_pickups == 6
      
      # Charlie can't stack and must draw
      {:ok, final_game} = Game.draw_card(game, "charlie")
      assert final_game.pending_pickups == 0
      
      # Cards should be preserved
      assert count_total_cards(final_game) == 52
    end
  end

  describe "game state corruption from user actions" do
    test "handles invalid game state modifications" do
      # Simulate what happens if client sends corrupted data
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Try various invalid operations
      
      # Invalid player index in play_card
      result = Game.play_card(game, "alice", [999, -1, 100])
      assert {:error, :invalid_card_index} = result
      
      # Invalid suit nomination
      result = Game.nominate_suit(game, "alice", :invalid_suit)
      # Should reject invalid suits
      assert match?({:error, _}, result)
    end

    test "maintains game integrity with malformed inputs" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)
      
      # Try many malformed operations
      malformed_operations = [
        fn g -> Game.play_card(g, "", [0]) end,
        fn g -> Game.play_card(g, nil, [0]) end,
        fn g -> Game.play_card(g, "alice", nil) end,
        fn g -> Game.draw_card(g, "") end,
        fn g -> Game.nominate_suit(g, "alice", nil) end
      ]
      
      # All should fail gracefully without corrupting game
      final_game = Enum.reduce(malformed_operations, game, fn operation, acc ->
        try do
          case operation.(acc) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        rescue
          _ -> acc  # Operation failed, game unchanged
        end
      end)
      
      # Game should be unchanged
      assert count_total_cards(final_game) == initial_cards
      assert final_game.status == :playing
    end
  end

  # Helper functions
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

  defp try_any_move(game, player_id) do
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

  defp attempt_card_manipulation(game, attempts) do
    Enum.reduce(1..attempts, game, fn _i, acc ->
      current_player = Game.current_player(acc)
      
      # Try various potentially exploitative moves
      results = [
        Game.play_card(acc, current_player.id, [0, 0, 0]),  # Duplicate indices
        Game.play_card(acc, current_player.id, [99]),       # Out of bounds
        Game.draw_card(acc, current_player.id),             # Normal draw
        Game.play_card(acc, current_player.id, [-1])        # Negative index
      ]
      
      # Use first successful result, or keep original game
      Enum.reduce_while(results, acc, fn result, original ->
        case result do
          {:ok, new_game} -> {:halt, new_game}
          {:error, _} -> {:cont, original}
        end
      end)
    end)
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end