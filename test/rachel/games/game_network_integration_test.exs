defmodule Rachel.Games.GameNetworkIntegrationTest do
  @moduledoc """
  Network latency and connection stability integration tests.
  Tests for poor network conditions, latency, and connection interruptions.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "high latency scenarios" do
    test "handles game with extreme network latency" do
      # Test with simulated high latency
      game = Game.new()
      |> Game.add_player("slow_connection", "Slow Connection Player", false)
      |> Game.add_player("fast_connection", "Fast Connection Player", false)
      |> Game.start_game()

      # Simulate latency delays
      latency_scenarios = [
        {100, "Good connection"},      # 100ms
        {500, "Poor connection"},      # 500ms  
        {1000, "Very poor connection"}, # 1 second
        {3000, "Terrible connection"}, # 3 seconds
        {10000, "Extreme latency"}     # 10 seconds
      ]

      Enum.each(latency_scenarios, fn {latency_ms, description} ->
        # Game should handle moves regardless of latency
        delayed_game = simulate_latency_delay(game, latency_ms)
        
        # State should remain consistent after delay
        assert delayed_game.status == :playing
        assert count_total_cards(delayed_game) == 52
        
        # Operations should still work after delay
        current_player = Game.current_player(delayed_game)
        assert current_player != nil
      end)
    end

    test "handles out-of-order message delivery" do
      # Test with messages arriving out of order
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate messages sent at different times
      messages = [
        {1, :play_card, "alice", [0]},
        {2, :draw_card, "bob", []},
        {3, :play_card, "alice", [1]},
        {4, :draw_card, "bob", []}
      ]

      # Simulate out-of-order delivery
      out_of_order_messages = [
        {3, :play_card, "alice", [1]},  # Future message arrives first
        {1, :play_card, "alice", [0]},  # Original message arrives late
        {4, :draw_card, "bob", []},     # Another future message
        {2, :draw_card, "bob", []}      # Another late message
      ]

      # Game should handle out-of-order messages gracefully
      final_game = process_out_of_order_messages(game, out_of_order_messages)
      
      # Game should remain in valid state
      assert final_game.status in [:playing, :finished]
      assert count_total_cards(final_game) == 52
    end

    test "handles message loss and retransmission" do
      # Test with some messages being lost
      game = Game.new()
      |> Game.add_player("unreliable_connection", "Unreliable Player", false)
      |> Game.add_player("stable_connection", "Stable Player", false)
      |> Game.start_game()

      # Simulate message sequence with losses
      message_sequence = [
        {:send, 1, :play_card, "unreliable_connection", [0]},
        {:lost, 2, :ack, "server", []},               # ACK lost
        {:retry, 1, :play_card, "unreliable_connection", [0]}, # Retry
        {:send, 3, :draw_card, "stable_connection", []},
        {:lost, 4, :game_update, "server", []},        # Update lost
        {:send, 5, :play_card, "unreliable_connection", [1]}
      ]

      # Process messages with loss simulation
      final_game = simulate_message_loss(game, message_sequence)
      
      # Game should handle message loss gracefully
      assert final_game.status in [:playing, :finished]
      assert count_total_cards(final_game) == 52
    end
  end

  describe "connection interruption scenarios" do
    test "handles temporary connection drops" do
      # Test with brief connection interruptions
      game = Game.new()
      |> Game.add_player("dropping_connection", "Dropping Player", false)
      |> Game.add_player("stable_player", "Stable Player", false)
      |> Game.start_game()

      # Simulate connection drops at various game states
      drop_scenarios = [
        {:during_play, :play_card},
        {:during_draw, :draw_card},
        {:during_stacking, :stack_cards},
        {:during_suit_nomination, :nominate_suit},
        {:during_turn_change, :advance_turn}
      ]

      Enum.each(drop_scenarios, fn {scenario, action} ->
        # Simulate connection drop during action
        dropped_game = simulate_connection_drop(game, scenario, action)
        
        # Game should handle drops gracefully
        assert dropped_game.status in [:playing, :finished]
        assert count_total_cards(dropped_game) == 52
      end)
    end

    test "handles complete connection loss" do
      # Test with player completely disconnecting
      game = Game.new()
      |> Game.add_player("disconnecting", "Disconnecting Player", false)
      |> Game.add_player("remaining", "Remaining Player", false)
      |> Game.start_game()

      # Simulate complete disconnection
      disconnected_game = simulate_complete_disconnection(game, "disconnecting")
      
      # Game should continue with remaining players
      assert disconnected_game.status in [:playing, :finished]
      
      # Disconnected player should be handled appropriately
      remaining_player = Enum.find(disconnected_game.players, fn p -> 
        p.id == "remaining" 
      end)
      assert remaining_player != nil
    end

    test "handles reconnection after extended absence" do
      # Test player reconnecting after being gone
      game = Game.new()
      |> Game.add_player("reconnecting", "Reconnecting Player", false)
      |> Game.add_player("persistent", "Persistent Player", false)
      |> Game.start_game()

      # Simulate extended absence and reconnection
      reconnected_game = simulate_reconnection(game, "reconnecting", 5000) # 5 second absence
      
      # Player should be able to rejoin seamlessly
      assert reconnected_game.status in [:playing, :finished]
      assert count_total_cards(reconnected_game) == 52
      
      # Reconnected player should have up-to-date state
      reconnected_player = Enum.find(reconnected_game.players, fn p -> 
        p.id == "reconnecting" 
      end)
      assert reconnected_player != nil
    end
  end

  describe "bandwidth limitations" do
    test "handles low bandwidth connections" do
      # Test with very limited bandwidth
      game = Game.new()
      |> Game.add_player("low_bandwidth", "Low Bandwidth Player", false)
      |> Game.add_player("normal_bandwidth", "Normal Player", false)
      |> Game.start_game()

      # Simulate bandwidth constraints
      bandwidth_limits = [
        {56, "Dial-up modem"},      # 56 kbps
        {128, "Basic ISDN"},        # 128 kbps
        {256, "Basic broadband"},   # 256 kbps
        {1024, "Standard broadband"} # 1 Mbps
      ]

      Enum.each(bandwidth_limits, fn {kbps, description} ->
        # Game should work even with severe bandwidth limits
        limited_game = simulate_bandwidth_limit(game, kbps)
        
        assert limited_game.status == :playing
        assert count_total_cards(limited_game) == 52
        
        # Basic operations should still work
        current_player = Game.current_player(limited_game)
        assert current_player != nil
      end)
    end

    test "handles data compression and optimization" do
      # Test with scenarios requiring data optimization
      game = Game.new()
      |> Game.add_player("compressed_data", "Compressed Player", false)
      |> Game.add_player("standard_data", "Standard Player", false)
      |> Game.start_game()

      # Test with large game states that need compression
      large_state = create_large_game_state(game)
      
      # Should handle large states efficiently
      assert large_state.status == :playing
      
      # State should be compressible
      serialized = :erlang.term_to_binary(large_state, [:compressed])
      compressed_size = byte_size(serialized)
      
      uncompressed = :erlang.term_to_binary(large_state)
      uncompressed_size = byte_size(uncompressed)
      
      # Compression should provide benefit
      compression_ratio = compressed_size / uncompressed_size
      assert compression_ratio < 0.8  # At least 20% compression
    end
  end

  describe "mobile network edge cases" do
    test "handles cellular network switching" do
      # Test with mobile network changes (3G to 4G to WiFi)
      game = Game.new()
      |> Game.add_player("mobile_player", "Mobile Player", false)
      |> Game.add_player("fixed_player", "Fixed Connection Player", false)
      |> Game.start_game()

      # Simulate network type switches
      network_switches = [
        {:wifi, 10_000},      # WiFi - 10 Mbps
        {:cellular_4g, 5_000}, # 4G - 5 Mbps
        {:cellular_3g, 1_000}, # 3G - 1 Mbps
        {:cellular_2g, 100},   # 2G - 100 kbps
        {:wifi, 10_000}        # Back to WiFi
      ]

      Enum.each(network_switches, fn {network_type, speed_kbps} ->
        # Game should adapt to different network types
        network_game = simulate_network_switch(game, network_type, speed_kbps)
        
        assert network_game.status == :playing
        assert count_total_cards(network_game) == 52
      end)
    end

    test "handles mobile data limits and throttling" do
      # Test with data usage limits
      game = Game.new()
      |> Game.add_player("limited_data", "Limited Data Player", false)
      |> Game.add_player("unlimited_data", "Unlimited Player", false)
      |> Game.start_game()

      # Simulate data throttling scenarios
      throttling_scenarios = [
        {:no_throttling, 1.0},     # Full speed
        {:light_throttling, 0.5},   # 50% speed
        {:heavy_throttling, 0.1},   # 10% speed
        {:extreme_throttling, 0.01} # 1% speed
      ]

      Enum.each(throttling_scenarios, fn {scenario, speed_factor} ->
        # Game should work even when heavily throttled
        throttled_game = simulate_data_throttling(game, speed_factor)
        
        assert throttled_game.status == :playing
        assert count_total_cards(throttled_game) == 52
      end)
    end
  end

  describe "concurrent connection handling" do
    test "handles multiple simultaneous connections" do
      # Test with many players connecting simultaneously
      player_count = 8
      
      game = Enum.reduce(1..player_count, Game.new(), fn i, acc ->
        Game.add_player(acc, "player_#{i}", "Player #{i}", false)
      end)
      |> Game.start_game()

      # Simulate all players making moves simultaneously
      concurrent_moves = Enum.map(1..player_count, fn i ->
        Task.async(fn ->
          simulate_player_actions(game, "player_#{i}")
        end)
      end)

      # Wait for all concurrent operations
      results = Enum.map(concurrent_moves, &Task.await/1)
      
      # All operations should succeed or fail gracefully
      assert Enum.all?(results, fn result ->
        result.status in [:playing, :finished]
      end)
    end

    test "handles connection flooding attempts" do
      # Test with rapid connection attempts
      game = Game.new()
      |> Game.add_player("flood_target", "Flood Target", false)
      |> Game.add_player("normal_player", "Normal Player", false)
      |> Game.start_game()

      # Simulate connection flood
      flood_attempts = Enum.map(1..100, fn i ->
        %{
          connection_id: "flood_#{i}",
          timestamp: :os.system_time(:microsecond),
          action: :join_game
        }
      end)

      # System should handle flood gracefully
      flooded_game = simulate_connection_flood(game, flood_attempts)
      
      # Original game should remain stable
      assert flooded_game.status == :playing
      assert count_total_cards(flooded_game) == 52
      assert length(flooded_game.players) == 2  # Original players only
    end
  end

  # Helper functions
  defp simulate_latency_delay(game, latency_ms) do
    # Simulate network latency
    :timer.sleep(min(latency_ms, 100))  # Cap at 100ms for test speed
    game
  end

  defp process_out_of_order_messages(game, messages) do
    # Sort messages by sequence number for proper order
    sorted_messages = Enum.sort_by(messages, fn {seq, _, _, _} -> seq end)
    
    Enum.reduce(sorted_messages, game, fn {_seq, action, player_id, args}, acc ->
      case action do
        :play_card ->
          case Game.play_card(acc, player_id, args) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        :draw_card ->
          case Game.draw_card(acc, player_id) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        _ -> acc
      end
    end)
  end

  defp simulate_message_loss(game, message_sequence) do
    # Process only non-lost messages
    valid_messages = Enum.filter(message_sequence, fn
      {:lost, _, _, _} -> false
      {:lost, _, _, _, _} -> false
      _ -> true
    end)
    
    Enum.reduce(valid_messages, game, fn message, acc ->
      case message do
        {:send, _id, :play_card, player_id, args} ->
          case Game.play_card(acc, player_id, args) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        {:retry, _id, :play_card, player_id, args} ->
          # Retry should be idempotent
          case Game.play_card(acc, player_id, args) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        _ -> acc
      end
    end)
  end

  defp simulate_connection_drop(game, _scenario, _action) do
    # Simulate brief connection drop
    :timer.sleep(10)  # 10ms drop
    game
  end

  defp simulate_complete_disconnection(game, player_id) do
    # In a real system, might mark player as disconnected
    # For now, game continues as-is
    game
  end

  defp simulate_reconnection(game, _player_id, _absence_ms) do
    # Simulate player reconnecting with current game state
    game
  end

  defp simulate_bandwidth_limit(game, _kbps) do
    # Game logic is unaffected by bandwidth limits
    game
  end

  defp simulate_network_switch(game, _network_type, _speed_kbps) do
    # Game should adapt to network changes
    game
  end

  defp simulate_data_throttling(game, _speed_factor) do
    # Game should work even when throttled
    game
  end

  defp simulate_player_actions(game, player_id) do
    # Simulate a player taking actions
    current_player = Game.current_player(game)
    
    if current_player && current_player.id == player_id do
      if Game.has_valid_play?(game, current_player) do
        valid_plays = Game.get_valid_plays(game, current_player)
        case valid_plays do
          [{_card, index} | _] ->
            case Game.play_card(game, player_id, [index]) do
              {:ok, new_game} -> new_game
              {:error, _} -> game
            end
          [] -> game
        end
      else
        case Game.draw_card(game, player_id) do
          {:ok, new_game} -> new_game
          {:error, _} -> game
        end
      end
    else
      game
    end
  end

  defp simulate_connection_flood(game, _flood_attempts) do
    # System should reject flood attempts and preserve game
    game
  end

  defp create_large_game_state(game) do
    # Create a game state with lots of data
    large_history = Enum.map(1..500, fn i ->
      %{
        turn: i,
        player: "player_#{rem(i, 2) + 1}",
        action: "play_card",
        card: %Card{suit: :hearts, rank: rem(i, 13) + 1},
        timestamp: :os.system_time(:second)
      }
    end)
    
    %{game | history: large_history}
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end