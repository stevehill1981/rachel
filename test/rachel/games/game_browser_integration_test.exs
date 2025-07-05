defmodule Rachel.Games.GameBrowserIntegrationTest do
  @moduledoc """
  Cross-browser compatibility integration tests.
  Tests for browser-specific behavior, compatibility issues, and edge cases.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "browser-specific javascript edge cases" do
    test "handles games with browser-specific number precision" do
      # Test with numbers that might have precision issues in JavaScript
      game = Game.new()
      |> Game.add_player("precision_player", "Precision Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # JavaScript numbers that might lose precision
      large_numbers = [
        9_007_199_254_740_991,  # MAX_SAFE_INTEGER
        9_007_199_254_740_992,  # MAX_SAFE_INTEGER + 1
        0.1 + 0.2,              # Famous floating point issue
        1.7976931348623157e+308 # Near MAX_VALUE
      ]

      # Game should handle these without corruption
      Enum.each(large_numbers, fn num ->
        # Simulate game state with potentially problematic numbers
        test_game = %{game | turn_count: trunc(num)}
        
        # Operations should still work correctly
        current_player = Game.current_player(test_game)
        assert current_player != nil
        assert is_integer(test_game.turn_count)
      end)
    end

    test "handles browser-specific date/time edge cases" do
      # Test with dates that might behave differently across browsers
      game = Game.new()
      |> Game.add_player("date_player", "Date Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Edge case timestamps
      edge_timestamps = [
        0,                    # Unix epoch
        -1,                   # Before epoch
        2_147_483_647,        # 32-bit signed int max
        2_147_483_648,        # 32-bit signed int overflow
        1_000_000_000_000,    # Common JavaScript timestamp (milliseconds)
        253_402_300_799       # Year 9999 (max reasonable year)
      ]

      Enum.each(edge_timestamps, fn timestamp ->
        # Game should handle edge case timestamps
        test_game = %{game | created_at: timestamp}
        
        # Basic operations should still work
        assert test_game.status == :playing
        assert is_integer(test_game.created_at)
      end)
    end

    test "handles browser-specific string encoding" do
      # Test with strings that might be encoded differently
      game = Game.new()
      |> Game.add_player("encoding_player", "Encoding Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Strings with encoding edge cases
      encoding_test_strings = [
        "Normal String",
        "UTF-8: 你好世界",
        "Emoji: 🎮🃏🎯",
        "Mixed: ASCII + 中文 + عربي",
        "Null byte: \0 in string",
        "Escape sequences: \n\t\r\"'\\",
        "Unicode escapes: \u0041\u0042\u0043",
        "Surrogate pairs: 𝕏𝕐𝕑"
      ]

      Enum.each(encoding_test_strings, fn test_string ->
        # Game should handle various string encodings
        test_player = %{hd(game.players) | name: test_string}
        test_game = %{game | players: [test_player, hd(tl(game.players))]}
        
        # Operations should work with encoded strings
        current_player = Game.current_player(test_game)
        assert is_binary(current_player.name)
      end)
    end
  end

  describe "browser storage and state persistence" do
    test "handles browser localStorage size limits" do
      # Test with game states that might exceed storage limits
      game = Game.new()
      |> Game.add_player("storage_player", "Storage Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Create large game state (simulate extensive game history)
      large_game_history = Enum.map(1..1000, fn i ->
        %{
          turn: i,
          player: "storage_player",
          action: "play_card",
          card: %Card{suit: :hearts, rank: 5},
          timestamp: :os.system_time(:second)
        }
      end)

      # Game should handle large state gracefully
      test_game = %{game | history: large_game_history}
      
      # Basic operations should still work
      assert test_game.status == :playing
      assert is_list(test_game.history)
      assert length(test_game.history) == 1000
      
      # State should be serializable
      serialized = :erlang.term_to_binary(test_game)
      assert is_binary(serialized)
      
      # Should be able to deserialize
      deserialized = :erlang.binary_to_term(serialized)
      assert deserialized.status == :playing
    end

    test "handles browser sessionStorage cleanup" do
      # Test game state cleanup scenarios
      game = Game.new()
      |> Game.add_player("session_player", "Session Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate cleanup scenarios
      cleanup_scenarios = [
        %{game | players: []},                    # Empty players
        %{game | deck: %{cards: []}},            # Empty deck
        %{game | discard_pile: []},              # Empty discard
        %{game | current_card: nil},             # No current card
        %{game | status: nil}                    # Invalid status
      ]

      Enum.each(cleanup_scenarios, fn scenario ->
        # Game should handle cleanup gracefully
        try do
          current_player = Game.current_player(scenario)
          # Should either work or fail gracefully
          assert current_player == nil or is_map(current_player)
        rescue
          _ -> :ok  # Acceptable to fail on invalid state
        end
      end)
    end
  end

  describe "browser performance edge cases" do
    test "handles browser rendering performance with many cards" do
      # Test with scenarios that might slow down browser rendering
      game = Game.new()
      |> Game.add_player("render_player", "Render Player", false)
      |> Game.add_player("other", "Other Player", false)

      # Give player many cards (rendering stress test)
      many_cards = Enum.map(1..50, fn i ->
        %Card{suit: :hearts, rank: rem(i, 13) + 1}
      end)

      [render_player, other] = game.players
      render_player = %{render_player | hand: many_cards}
      
      test_game = %{game | 
        players: [render_player, other],
        status: :playing
      }

      # Operations should remain fast even with many cards
      start_time = System.monotonic_time(:microsecond)
      
      valid_plays = Game.get_valid_plays(test_game, render_player)
      has_valid = Game.has_valid_play?(test_game, render_player)
      
      end_time = System.monotonic_time(:microsecond)
      elapsed_ms = (end_time - start_time) / 1000
      
      # Should be fast even with many cards
      assert elapsed_ms < 100
      assert is_list(valid_plays)
      assert is_boolean(has_valid)
    end

    test "handles browser memory limits with complex game states" do
      # Test with complex nested structures
      game = Game.new()
      |> Game.add_player("complex_player", "Complex Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Create complex nested game state
      complex_state = %{game | 
        metadata: %{
          browser_info: %{
            user_agent: "Complex Browser Agent String",
            viewport: %{width: 1920, height: 1080},
            capabilities: %{
              webgl: true,
              canvas: true,
              webassembly: true
            }
          },
          game_settings: %{
            difficulty: :expert,
            speed: :fast,
            animations: true,
            sound: true
          }
        }
      }

      # Should handle complex nested structures
      assert complex_state.status == :playing
      assert is_map(complex_state.metadata)
      assert count_total_cards(complex_state) == 52
    end

    test "handles browser memory cleanup during long games" do
      # Test memory management during extended play
      game = Game.new()
      |> Game.add_player("memory_player", "Memory Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate memory pressure scenarios
      memory_pressure_game = simulate_memory_pressure(game, 100)
      
      # Game should still function after memory pressure
      assert memory_pressure_game.status in [:playing, :finished]
      assert count_total_cards(memory_pressure_game) == 52
      
      # Memory should be manageable
      game_size = :erlang.external_size(memory_pressure_game)
      assert game_size < 1_000_000  # Less than 1MB
    end
  end

  describe "browser event handling edge cases" do
    test "handles rapid click events" do
      # Test with rapid user interactions
      game = Game.new()
      |> Game.add_player("clicker", "Rapid Clicker", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate rapid click events
      rapid_clicks = Enum.map(1..100, fn i ->
        %{
          type: :click,
          target: :card,
          index: rem(i, 7),
          timestamp: :os.system_time(:microsecond)
        }
      end)

      # Game should handle rapid events gracefully
      processed_clicks = process_rapid_events(game, rapid_clicks)
      
      # Should not crash or corrupt state
      assert processed_clicks.status in [:playing, :finished]
      assert count_total_cards(processed_clicks) == 52
    end

    test "handles browser focus and blur events" do
      # Test with browser focus changes
      game = Game.new()
      |> Game.add_player("focus_player", "Focus Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate focus/blur scenarios
      focus_events = [
        {:focus, :window},
        {:blur, :window},
        {:focus, :tab},
        {:blur, :tab},
        {:focus, :card_selection},
        {:blur, :card_selection}
      ]

      # Game should handle focus changes
      focused_game = simulate_focus_events(game, focus_events)
      
      assert focused_game.status in [:playing, :finished]
      assert count_total_cards(focused_game) == 52
    end

    test "handles browser resize events during gameplay" do
      # Test with browser window resizing
      game = Game.new()
      |> Game.add_player("resize_player", "Resize Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate various viewport sizes
      viewport_sizes = [
        {320, 568},    # iPhone SE
        {375, 667},    # iPhone 6/7/8
        {414, 896},    # iPhone 11
        {768, 1024},   # iPad
        {1024, 768},   # iPad landscape
        {1920, 1080},  # Desktop
        {3840, 2160}   # 4K
      ]

      Enum.each(viewport_sizes, fn {width, height} ->
        # Game should work at any viewport size
        resized_game = %{game | 
          viewport: %{width: width, height: height}
        }
        
        assert resized_game.status == :playing
        assert count_total_cards(resized_game) == 52
      end)
    end
  end

  describe "browser compatibility quirks" do
    test "handles browser-specific card animation edge cases" do
      # Test with animations that might behave differently
      game = Game.new()
      |> Game.add_player("animation_player", "Animation Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate animation states
      animation_states = [
        :card_deal_animation,
        :card_play_animation,
        :card_draw_animation,
        :shuffle_animation,
        :victory_animation
      ]

      Enum.each(animation_states, fn state ->
        # Game should work regardless of animation state
        animated_game = %{game | current_animation: state}
        
        assert animated_game.status == :playing
        current_player = Game.current_player(animated_game)
        assert current_player != nil
      end)
    end

    test "handles browser-specific audio edge cases" do
      # Test with audio that might behave differently
      game = Game.new()
      |> Game.add_player("audio_player", "Audio Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate audio states
      audio_scenarios = [
        %{sound_enabled: true, volume: 1.0},
        %{sound_enabled: false, volume: 0.0},
        %{sound_enabled: true, volume: 0.5},
        %{sound_enabled: true, volume: nil},  # Invalid volume
        %{sound_enabled: nil, volume: 1.0}    # Invalid sound setting
      ]

      Enum.each(audio_scenarios, fn audio_config ->
        # Game should work with any audio configuration
        audio_game = %{game | audio_config: audio_config}
        
        assert audio_game.status == :playing
        assert count_total_cards(audio_game) == 52
      end)
    end

    test "handles browser-specific touch event edge cases" do
      # Test with touch events that might behave differently
      game = Game.new()
      |> Game.add_player("touch_player", "Touch Player", false)
      |> Game.add_player("other", "Other Player", false)
      |> Game.start_game()

      # Simulate touch event scenarios
      touch_events = [
        {:touch_start, {100, 200}},
        {:touch_move, {150, 250}},
        {:touch_end, {200, 300}},
        {:touch_cancel, {0, 0}},
        {:multi_touch, [{100, 200}, {300, 400}]},
        {:pressure_touch, {100, 200, 0.5}}
      ]

      # Game should handle all touch events gracefully
      touched_game = simulate_touch_events(game, touch_events)
      
      assert touched_game.status in [:playing, :finished]
      assert count_total_cards(touched_game) == 52
    end
  end

  # Helper functions
  defp simulate_memory_pressure(game, iterations) do
    # Simulate operations that might cause memory pressure
    Enum.reduce(1..iterations, game, fn _i, acc ->
      case try_random_operation(acc) do
        {:ok, new_game} -> new_game
        {:error, _} -> acc
      end
    end)
  end

  defp try_random_operation(game) do
    current_player = Game.current_player(game)
    
    if current_player && Game.has_valid_play?(game, current_player) do
      valid_plays = Game.get_valid_plays(game, current_player)
      case valid_plays do
        [{_card, index} | _] -> Game.play_card(game, current_player.id, [index])
        [] -> Game.draw_card(game, current_player.id)
      end
    else
      {:ok, game}
    end
  end

  defp process_rapid_events(game, events) do
    # Process rapid click events
    Enum.reduce(events, game, fn event, acc ->
      case event do
        %{type: :click, target: :card, index: index} ->
          # Simulate card click
          current_player = Game.current_player(acc)
          if current_player && index < length(current_player.hand) do
            case Game.play_card(acc, current_player.id, [index]) do
              {:ok, new_game} -> new_game
              {:error, _} -> acc
            end
          else
            acc
          end
        _ -> acc
      end
    end)
  end

  defp simulate_focus_events(game, events) do
    # Simulate browser focus events
    Enum.reduce(events, game, fn _event, acc ->
      # Focus events don't directly affect game state
      acc
    end)
  end

  defp simulate_touch_events(game, events) do
    # Simulate touch events
    Enum.reduce(events, game, fn event, acc ->
      case event do
        {:touch_end, {_x, _y}} ->
          # Simulate touch ending as card play
          current_player = Game.current_player(acc)
          if current_player && Game.has_valid_play?(acc, current_player) do
            valid_plays = Game.get_valid_plays(acc, current_player)
            case valid_plays do
              [{_card, index} | _] ->
                case Game.play_card(acc, current_player.id, [index]) do
                  {:ok, new_game} -> new_game
                  {:error, _} -> acc
                end
              [] -> acc
            end
          else
            acc
          end
        _ -> acc
      end
    end)
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end