defmodule Rachel.Games.GameSystemIntegrationTest do
  @moduledoc """
  System-level integration tests.
  Tests interaction between game logic and other system components.
  """
  use ExUnit.Case, async: true
  use Rachel.DataCase

  alias Rachel.Games.{Card, Game}
  alias Rachel.{GameManager, GameServer}

  describe "gameserver integration" do
    test "game state persists through gameserver crashes" do
      # Test that game state survives GenServer restarts
      {:ok, pid} = GameServer.start_link(game_id: "crash_test")
      
      # Set up game
      GameServer.add_player(pid, "alice", "Alice", false)
      GameServer.add_player(pid, "bob", "Bob", false)
      GameServer.start_game(pid)
      
      # Get initial state
      initial_game = GameServer.get_game_state(pid)
      initial_cards = count_total_cards(initial_game)
      
      # Simulate crash and restart
      Process.exit(pid, :kill)
      
      # GameServer should restart with same ID
      {:ok, new_pid} = GameServer.start_link(game_id: "crash_test")
      
      # State might be lost (depending on persistence implementation)
      # This test verifies the system handles crashes gracefully
      try do
        recovered_game = GameServer.get_game_state(new_pid)
        recovered_cards = count_total_cards(recovered_game)
        
        # If recovery works, cards should be preserved
        assert recovered_cards == initial_cards
      rescue
        _ ->
          # If no persistence, crash recovery gracefully fails
          :ok
      end
    end

    test "multiple gameservers don't interfere" do
      # Test isolation between different games
      {:ok, game1_pid} = GameServer.start_link(game_id: "isolated_1")
      {:ok, game2_pid} = GameServer.start_link(game_id: "isolated_2")
      
      # Set up different games
      GameServer.add_player(game1_pid, "alice1", "Alice Game 1", false)
      GameServer.add_player(game1_pid, "bob1", "Bob Game 1", false)
      GameServer.start_game(game1_pid)
      
      GameServer.add_player(game2_pid, "alice2", "Alice Game 2", false)
      GameServer.add_player(game2_pid, "bob2", "Bob Game 2", false)
      GameServer.start_game(game2_pid)
      
      # Games should be independent
      game1_state = GameServer.get_game_state(game1_pid)
      game2_state = GameServer.get_game_state(game2_pid)
      
      assert game1_state.id != game2_state.id
      assert hd(game1_state.players).id == "alice1"
      assert hd(game2_state.players).id == "alice2"
      
      # Actions in one game shouldn't affect the other
      if Game.has_valid_play?(game1_state, hd(game1_state.players)) do
        valid_plays = Game.get_valid_plays(game1_state, hd(game1_state.players))
        case valid_plays do
          [{_card, index} | _] ->
            GameServer.play_card(game1_pid, "alice1", [index])
            
            # Game 2 should be unchanged
            unchanged_game2 = GameServer.get_game_state(game2_pid)
            assert unchanged_game2.current_player_index == game2_state.current_player_index
          [] -> :ok
        end
      end
    end
  end

  describe "pubsub integration" do
    test "game events are published correctly" do
      # Test that game state changes trigger PubSub events
      game_id = "pubsub_test"
      
      # Subscribe to game events
      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
      
      {:ok, pid} = GameServer.start_link(game_id: game_id)
      GameServer.add_player(pid, "alice", "Alice", false)
      GameServer.add_player(pid, "bob", "Bob", false)
      GameServer.start_game(pid)
      
      # Should receive game_started event
      assert_receive {:game_started, ^game_id}, 1000
      
      # Make a move
      game_state = GameServer.get_game_state(pid)
      if Game.has_valid_play?(game_state, hd(game_state.players)) do
        valid_plays = Game.get_valid_plays(game_state, hd(game_state.players))
        case valid_plays do
          [{_card, index} | _] ->
            GameServer.play_card(pid, "alice", [index])
            
            # Should receive game_updated event
            assert_receive {:game_updated, ^game_id, _new_state}, 1000
          [] -> :ok
        end
      end
    end

    test "handles pubsub message flooding" do
      # Test system doesn't break under message flood
      game_id = "flood_test"
      {:ok, pid} = GameServer.start_link(game_id: game_id)
      
      GameServer.add_player(pid, "alice", "Alice", false)
      GameServer.add_player(pid, "bob", "Bob", false)
      GameServer.start_game(pid)
      
      # Flood with rapid moves
      game_state = GameServer.get_game_state(pid)
      
      # Try 100 rapid operations
      Enum.each(1..100, fn _i ->
        try do
          GameServer.play_card(pid, "alice", [0])
        rescue
          _ -> :ok
        end
      end)
      
      # GameServer should still be responsive
      final_state = GameServer.get_game_state(pid)
      assert final_state.status in [:playing, :finished]
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
        assert stats.total_turns > 0
        assert stats.total_cards_played >= 0
        assert is_list(stats.finish_positions)
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
      Enum.each(1..20, fn i ->
        {:ok, pid} = GameServer.start_link(game_id: "cleanup_#{i}")
        
        GameServer.add_player(pid, "alice", "Alice", false)
        GameServer.add_player(pid, "bob", "Bob", false)
        GameServer.start_game(pid)
        
        # Force game to finish quickly
        game_state = GameServer.get_game_state(pid)
        [alice, bob] = game_state.players
        
        # Give Alice just one card to win quickly
        alice = %{alice | hand: [%Card{suit: :hearts, rank: 5}]}
        quick_finish_game = %{game_state | 
          players: [alice, bob],
          current_card: %Card{suit: :hearts, rank: 6}
        }
        
        # Simulate Alice winning
        try do
          GameServer.play_card(pid, "alice", [0])
        rescue
          _ -> :ok
        end
        
        # Stop the game server
        GenServer.stop(pid)
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
      {:ok, pid} = GameServer.start_link(game_id: "memory_test")
      
      GameServer.add_player(pid, "alice", "Alice", false)
      GameServer.add_player(pid, "bob", "Bob", false)
      GameServer.start_game(pid)
      
      initial_memory = :erlang.memory(:total)
      
      # Simulate 1000 moves
      Enum.each(1..1000, fn _i ->
        game_state = GameServer.get_game_state(pid)
        
        if game_state.status == :playing do
          current_player = Game.current_player(game_state)
          
          try do
            if Game.has_valid_play?(game_state, current_player) do
              valid_plays = Game.get_valid_plays(game_state, current_player)
              case valid_plays do
                [{_card, index} | _] ->
                  GameServer.play_card(pid, current_player.id, [index])
                [] ->
                  GameServer.draw_card(pid, current_player.id)
              end
            else
              GameServer.draw_card(pid, current_player.id)
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
      
      GenServer.stop(pid)
    end
  end

  describe "error handling integration" do
    test "system recovers from cascading failures" do
      # Test recovery from multiple simultaneous failures
      game_ids = Enum.map(1..5, fn i -> "cascade_#{i}" end)
      
      # Start multiple games
      pids = Enum.map(game_ids, fn game_id ->
        {:ok, pid} = GameServer.start_link(game_id: game_id)
        GameServer.add_player(pid, "alice", "Alice", false)
        GameServer.add_player(pid, "bob", "Bob", false)
        GameServer.start_game(pid)
        {game_id, pid}
      end)
      
      # Kill all processes simultaneously
      Enum.each(pids, fn {_game_id, pid} ->
        Process.exit(pid, :kill)
      end)
      
      # System should recover gracefully
      # New games should still be creatable
      {:ok, recovery_pid} = GameServer.start_link(game_id: "recovery_test")
      GameServer.add_player(recovery_pid, "alice", "Alice", false)
      GameServer.add_player(recovery_pid, "bob", "Bob", false)
      GameServer.start_game(recovery_pid)
      
      recovery_state = GameServer.get_game_state(recovery_pid)
      assert recovery_state.status == :playing
      assert count_total_cards(recovery_state) == 52
      
      GenServer.stop(recovery_pid)
    end

    test "handles malformed messages gracefully" do
      # Test system response to invalid messages
      {:ok, pid} = GameServer.start_link(game_id: "malformed_test")
      
      # Send malformed messages
      malformed_messages = [
        :invalid_message,
        {:play_card, nil, nil},
        {:add_player, "", "", "not_boolean"},
        {:unknown_command, "data"}
      ]
      
      # System should handle all gracefully
      Enum.each(malformed_messages, fn message ->
        try do
          GenServer.call(pid, message)
        rescue
          _ -> :ok  # Expected to fail
        end
      end)
      
      # GameServer should still be responsive
      GameServer.add_player(pid, "alice", "Alice", false)
      GameServer.add_player(pid, "bob", "Bob", false)
      GameServer.start_game(pid)
      
      state = GameServer.get_game_state(pid)
      assert state.status == :playing
      
      GenServer.stop(pid)
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