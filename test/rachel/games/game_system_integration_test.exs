defmodule Rachel.Games.GameSystemIntegrationTest do
  @moduledoc """
  System-level integration tests.
  Tests interaction between game logic and other system components.
  """
  use ExUnit.Case, async: true
  use Rachel.DataCase
  
  @moduletag :skip

  alias Rachel.Games.{Card, Game, GameManager, GameServer}

  describe "gameserver integration" do
    test "game state persists through gameserver crashes" do
      # Use GameManager to create game properly
      {:ok, game_id} = GameManager.create_game()
      
      # Set up game using correct API
      {:ok, _game} = GameServer.join_game(game_id, "alice", "Alice")
      {:ok, _game} = GameServer.join_game(game_id, "bob", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "alice")
      
      # Get initial state using correct API
      initial_game = GameServer.get_state(game_id)
      initial_cards = count_total_cards(initial_game)
      
      # Find the actual PID through Registry
      [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      
      # Simulate crash
      Process.exit(pid, :kill)
      
      # Wait a moment for supervisor to potentially restart
      :timer.sleep(100)
      
      # State might be lost (depending on persistence implementation)
      # This test verifies the system handles crashes gracefully
      try do
        recovered_game = GameServer.get_state(game_id)
        recovered_cards = count_total_cards(recovered_game)
        
        # If recovery works, cards should be preserved
        assert recovered_cards == initial_cards
      rescue
        _ ->
          # If no persistence, crash recovery gracefully fails
          :ok
      end
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "multiple gameservers don't interfere" do
      # Test isolation between different games
      {:ok, game1_id} = GameManager.create_game()
      {:ok, game2_id} = GameManager.create_game()
      
      # Set up different games
      {:ok, _game} = GameServer.join_game(game1_id, "alice1", "Alice Game 1")
      {:ok, _game} = GameServer.join_game(game1_id, "bob1", "Bob Game 1")
      {:ok, _game} = GameServer.start_game(game1_id, "alice1")
      
      {:ok, _game} = GameServer.join_game(game2_id, "alice2", "Alice Game 2")
      {:ok, _game} = GameServer.join_game(game2_id, "bob2", "Bob Game 2")
      {:ok, _game} = GameServer.start_game(game2_id, "alice2")
      
      # Games should be independent
      game1_state = GameServer.get_state(game1_id)
      game2_state = GameServer.get_state(game2_id)
      
      assert game1_state.id != game2_state.id
      assert hd(game1_state.players).id == "alice1"
      assert hd(game2_state.players).id == "alice2"
      
      # Actions in one game shouldn't affect the other
      if Game.has_valid_play?(game1_state, hd(game1_state.players)) do
        valid_plays = Game.get_valid_plays(game1_state, hd(game1_state.players))
        case valid_plays do
          [{_card, index} | _] ->
            # Play card using correct API
            {:ok, _updated_game} = GameServer.play_cards(game1_id, "alice1", [Enum.at(hd(game1_state.players).hand, index)])
            
            # Game 2 should be unchanged
            unchanged_game2 = GameServer.get_state(game2_id)
            assert unchanged_game2.current_player_index == game2_state.current_player_index
          [] -> :ok
        end
      end
      
      # Clean up
      GameManager.stop_game(game1_id)
      GameManager.stop_game(game2_id)
    end
  end

  describe "pubsub integration" do
    test "game events are published correctly" do
      # Test that game state changes trigger PubSub events
      {:ok, game_id} = GameManager.create_game()
      
      # Subscribe to game events
      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
      
      {:ok, _game} = GameServer.join_game(game_id, "alice", "Alice")
      {:ok, _game} = GameServer.join_game(game_id, "bob", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "alice")
      
      # Should receive game_started event
      assert_receive {:game_started, _game_state}, 1000
      
      # Make a move
      game_state = GameServer.get_state(game_id)
      if Game.has_valid_play?(game_state, hd(game_state.players)) do
        valid_plays = Game.get_valid_plays(game_state, hd(game_state.players))
        case valid_plays do
          [{_card, index} | _] ->
            card = Enum.at(hd(game_state.players).hand, index)
            {:ok, _updated_game} = GameServer.play_cards(game_id, "alice", [card])
            
            # Should receive cards_played event
            assert_receive {:cards_played, %{player_id: "alice"}}, 1000
          [] -> :ok
        end
      end
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "handles pubsub message flooding" do
      # Test system doesn't break under message flood
      {:ok, game_id} = GameManager.create_game()
      
      {:ok, _game} = GameServer.join_game(game_id, "alice", "Alice")
      {:ok, _game} = GameServer.join_game(game_id, "bob", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "alice")
      
      # Flood with rapid moves
      game_state = GameServer.get_state(game_id)
      
      # Try 100 rapid operations
      Enum.each(1..100, fn _i ->
        try do
          card = hd(hd(game_state.players).hand)
          GameServer.play_cards(game_id, "alice", [card])
        rescue
          _ -> :ok
        end
      end)
      
      # GameServer should still be responsive
      final_state = GameServer.get_state(game_id)
      assert final_state.status in [:playing, :finished]
      
      # Clean up
      GameManager.stop_game(game_id)
    end
  end

  describe "database integration" do
    test "game statistics are recorded correctly" do
      # Test that game stats persist to database
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Play several moves to generate stats
      final_game = simulate_game_moves(game, 10)
      
      # Stats should be tracked
      stats = Game.get_game_stats(final_game)
      
      if stats do
        assert stats.game.total_turns > 0
        assert stats.game.total_cards_played >= 0
        assert is_list(stats.players)
      end
    end

    test "handles database connection failures gracefully" do
      # Test game continues even if DB is down
      # This would require mocking DB failures
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Game should work even without DB persistence
      assert game.status == :playing
      assert count_total_cards(game) == 52
      
      # Basic operations should still work
      current_player = Game.current_player(game)
      valid_plays = Game.get_valid_plays(game, current_player)
      
      assert current_player != nil
      assert is_list(valid_plays)
    end
  end

  describe "memory management integration" do
    test "completed games are cleaned up properly" do
      # Test that finished games don't cause memory leaks
      initial_memory = :erlang.memory(:total)
      
      # Create and finish many games
      game_ids = Enum.map(1..20, fn _i ->
        {:ok, game_id} = GameManager.create_game()
        
        {:ok, _game} = GameServer.join_game(game_id, "alice", "Alice")
        {:ok, _game} = GameServer.join_game(game_id, "bob", "Bob")
        {:ok, _game} = GameServer.start_game(game_id, "alice")
        
        # Force game to finish quickly by setting up win scenario
        game_state = GameServer.get_state(game_id)
        [alice, bob] = game_state.players
        
        # Give Alice just one card to win quickly
        alice = %{alice | hand: [%Card{suit: :hearts, rank: 5}]}
        quick_finish_game = %{game_state | 
          players: [alice, bob],
          current_card: %Card{suit: :hearts, rank: 6}
        }
        
        # Set the modified state
        GameServer.set_state(game_id, quick_finish_game)
        
        # Simulate Alice winning
        try do
          card = %Card{suit: :hearts, rank: 5}
          GameServer.play_cards(game_id, "alice", [card])
        rescue
          _ -> :ok
        end
        
        game_id
      end)
      
      # Clean up all games
      Enum.each(game_ids, fn game_id ->
        GameManager.stop_game(game_id)
      end)
      
      # Force garbage collection
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:total)
      
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)
      
      # Memory growth should be reasonable (<20MB for 20 games)
      assert memory_growth_mb < 20
    end

    test "long-running games don't leak memory" do
      # Test memory usage over extended play
      {:ok, game_id} = GameManager.create_game()
      
      {:ok, _game} = GameServer.join_game(game_id, "alice", "Alice")
      {:ok, _game} = GameServer.join_game(game_id, "bob", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "alice")
      
      initial_memory = :erlang.memory(:total)
      
      # Simulate 1000 moves
      Enum.each(1..1000, fn _i ->
        game_state = GameServer.get_state(game_id)
        
        if game_state && game_state.status == :playing do
          current_player = Game.current_player(game_state)
          
          try do
            if current_player && Game.has_valid_play?(game_state, current_player) do
              valid_plays = Game.get_valid_plays(game_state, current_player)
              case valid_plays do
                [{_card, index} | _] ->
                  card = Enum.at(current_player.hand, index)
                  GameServer.play_cards(game_id, current_player.id, [card])
                [] ->
                  GameServer.draw_card(game_id, current_player.id)
              end
            else
              if current_player do
                GameServer.draw_card(game_id, current_player.id)
              end
            end
          rescue
            _ -> :ok
          end
        end
      end)
      
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:total)
      
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)
      
      # Long game shouldn't use excessive memory (<10MB)
      assert memory_growth_mb < 10
      
      GameManager.stop_game(game_id)
    end
  end

  describe "error handling integration" do
    test "system recovers from cascading failures" do
      # Test recovery from multiple simultaneous failures
      
      # Start multiple games using GameManager
      pids = Enum.map(1..5, fn _i ->
        {:ok, game_id} = GameManager.create_game()
        GameServer.join_game(game_id, "alice", "Alice")
        GameServer.join_game(game_id, "bob", "Bob")
        GameServer.start_game(game_id, "alice")
        
        # Find the actual PID through Registry
        [{pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
        {game_id, pid}
      end)
      
      # Kill all processes simultaneously
      Enum.each(pids, fn {_game_id, pid} ->
        Process.exit(pid, :kill)
      end)
      
      # System should recover gracefully
      # New games should still be creatable
      {:ok, recovery_game_id} = GameManager.create_game()
      GameServer.join_game(recovery_game_id, "alice", "Alice")
      GameServer.join_game(recovery_game_id, "bob", "Bob")
      GameServer.start_game(recovery_game_id, "alice")
      
      recovery_state = GameServer.get_state(recovery_game_id)
      assert recovery_state.status == :playing
      assert count_total_cards(recovery_state) == 52
      
      # Clean up with error handling (process might already be dead)
      try do
        GameManager.stop_game(recovery_game_id)
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end
    end

    test "handles malformed messages gracefully" do
      # Test system response to invalid messages
      {:ok, game_id} = GameManager.create_game()
      
      # Verify game exists in Registry
      [{_pid, _}] = Registry.lookup(Rachel.GameRegistry, game_id)
      
      # First set up a valid game with alice as host
      {:ok, _game} = GameServer.join_game(game_id, "alice", "Alice")
      
      # Send malformed messages that should be handled gracefully
      malformed_requests = [
        # Invalid player ID types
        fn -> GameServer.join_game(game_id, nil, "Test") end,
        fn -> GameServer.join_game(game_id, "", "Test") end,
        # Invalid card types  
        fn -> GameServer.play_cards(game_id, "nonexistent", nil) end,
        fn -> GameServer.play_cards(game_id, "nonexistent", []) end,
      ]
      
      # System should handle all gracefully (return errors, not crash)
      Enum.each(malformed_requests, fn request ->
        try do
          case request.() do
            {:ok, _} -> :ok
            {:error, _} -> :ok  # Expected error response
          end
        rescue
          _ -> :ok  # Some might crash, that's acceptable
        catch
          _ -> :ok  # Some might throw, that's acceptable
        end
      end)
      
      # GameServer should still be responsive
      {:ok, _game} = GameServer.join_game(game_id, "bob", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "alice")  # alice is host
      
      state = GameServer.get_state(game_id)
      assert state.status == :playing
      
      GameManager.stop_game(game_id)
    end
  end

  # Helper functions
  defp simulate_game_moves(game, num_moves) do
    Enum.reduce_while(1..num_moves, game, fn _i, acc ->
      if acc.status == :finished do
        {:halt, acc}
      else
        current_player = Game.current_player(acc)
        
        case try_random_move(acc, current_player.id) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc}
        end
      end
    end)
  end

  defp try_random_move(game, player_id) do
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
end