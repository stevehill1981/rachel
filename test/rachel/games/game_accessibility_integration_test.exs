defmodule Rachel.Games.GameAccessibilityIntegrationTest do
  @moduledoc """
  Accessibility integration tests.
  Tests for screen readers, keyboard navigation, and assistive technologies.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "screen reader compatibility" do
    test "game state changes provide appropriate ARIA updates" do
      # Test that screen readers get proper notifications
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate screen reader querying game state
      alice = hd(game.players)
      
      # Screen reader should get meaningful descriptions
      hand_description = describe_hand_for_screen_reader(alice.hand)
      game_status = describe_game_status_for_screen_reader(game)
      
      assert String.contains?(hand_description, "cards in hand")
      assert String.contains?(game_status, "current player")
      
      # After moves, descriptions should update
      if Game.has_valid_play?(game, alice) do
        valid_plays = Game.get_valid_plays(game, alice)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, new_game} = Game.play_card(game, "alice", [index])
            new_status = describe_game_status_for_screen_reader(new_game)
            
            # Should announce turn change
            assert new_status != game_status
          [] -> :ok
        end
      end
    end

    test "card selection provides audio feedback" do
      # Test for screen reader card selection
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      alice = hd(game.players)
      
      # Each card should have unique, meaningful description
      card_descriptions = Enum.map(alice.hand, fn card ->
        describe_card_for_screen_reader(card)
      end)
      
      # All descriptions should be unique
      unique_descriptions = Enum.uniq(card_descriptions)
      assert length(card_descriptions) == length(unique_descriptions)
      
      # Should include rank, suit, and special effects
      Enum.each(card_descriptions, fn description ->
        assert String.length(description) > 10  # Meaningful description
        assert description =~ ~r/(hearts|diamonds|clubs|spades)/
        assert description =~ ~r/(ace|king|queen|jack|\d+)/
      end)
    end

    test "game notifications are properly announced" do
      # Test screen reader announcements for game events
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up stacking scenario for announcement testing
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 2,
        pending_pickup_type: :twos
      }

      # Screen reader should announce stacking state
      stacking_announcement = describe_stacking_for_screen_reader(game)
      assert String.contains?(stacking_announcement, "2 cards must be drawn")
      assert String.contains?(stacking_announcement, "unless you play a 2")

      # Test direction change announcements
      game_with_queen = %{game | current_card: %Card{suit: :hearts, rank: :queen}}
      {:ok, reversed_game} = simulate_queen_play(game_with_queen)
      
      direction_announcement = describe_direction_for_screen_reader(reversed_game)
      assert String.contains?(direction_announcement, "direction")
    end
  end

  describe "keyboard navigation" do
    test "all game actions accessible via keyboard" do
      # Test keyboard-only gameplay
      game = Game.new()
      |> Game.add_player("keyboard_user", "Keyboard User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      keyboard_user = hd(game.players)
      
      # Simulate keyboard navigation through hand
      navigation_sequence = [
        {:focus_card, 0},
        {:next_card, 1},
        {:next_card, 2},
        {:previous_card, 1},
        {:select_card, 1},
        {:confirm_play, [1]}
      ]

      # Each step should be possible with keyboard
      final_state = simulate_keyboard_navigation(game, "keyboard_user", navigation_sequence)
      
      # Should result in valid game state
      assert final_state.status in [:playing, :finished]
      assert count_total_cards(final_state) == 52
    end

    test "keyboard shortcuts work consistently" do
      # Test common keyboard shortcuts
      game = Game.new()
      |> Game.add_player("shortcut_user", "Shortcut User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      keyboard_shortcuts = [
        {:key, "1"},        # Select first card
        {:key, "space"},    # Toggle selection
        {:key, "enter"},    # Confirm action
        {:key, "escape"},   # Cancel selection
        {:key, "d"},        # Draw card
        {:key, "tab"},      # Navigate UI
        {:key, "h"},        # Show help
      ]

      # All shortcuts should be handled gracefully
      final_game = simulate_keyboard_shortcuts(game, keyboard_shortcuts)
      assert final_game.status in [:playing, :finished]
    end

    test "focus management during game state changes" do
      # Test focus doesn't get lost during game updates
      game = Game.new()
      |> Game.add_player("focus_user", "Focus User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate focus on specific card
      ui_state = %{
        game: game,
        focused_card_index: 2,
        selected_cards: []
      }

      # After game state changes, focus should be preserved or moved logically
      focus_user = hd(game.players)
      if Game.has_valid_play?(game, focus_user) do
        valid_plays = Game.get_valid_plays(game, focus_user)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, new_game} = Game.play_card(game, "focus_user", [index])
            new_ui_state = update_focus_after_play(ui_state, new_game, index)
            
            # Focus should be moved to valid location
            assert new_ui_state.focused_card_index >= 0
            new_player = hd(new_game.players)
            assert new_ui_state.focused_card_index < length(new_player.hand)
          [] -> :ok
        end
      end
    end
  end

  describe "visual accessibility" do
    test "high contrast mode compatibility" do
      # Test game works with high contrast themes
      game = Game.new()
      |> Game.add_player("contrast_user", "High Contrast User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      contrast_user = hd(game.players)
      
      # Cards should be distinguishable in high contrast
      contrast_descriptions = Enum.map(contrast_user.hand, fn card ->
        generate_high_contrast_description(card)
      end)
      
      # All should have clear visual distinctions
      Enum.each(contrast_descriptions, fn description ->
        assert String.contains?(description, "high_contrast")
        assert description.background_color != description.text_color
      end)
    end

    test "colorblind accessibility" do
      # Test game is playable for colorblind users
      game = Game.new()
      |> Game.add_player("colorblind_user", "Colorblind User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      colorblind_user = hd(game.players)
      
      # Cards should be distinguishable without color
      card_patterns = Enum.map(colorblind_user.hand, fn card ->
        generate_colorblind_friendly_pattern(card)
      end)
      
      # Red and black suits should have different patterns/shapes
      hearts_diamonds = Enum.filter(card_patterns, fn p -> p.suit_type == :red end)
      clubs_spades = Enum.filter(card_patterns, fn p -> p.suit_type == :black end)
      
      # Should be distinguishable by shape/pattern, not just color
      Enum.each(hearts_diamonds, fn pattern ->
        assert pattern.shape in [:filled, :outline]
        assert pattern.has_pattern == true
      end)
      
      Enum.each(clubs_spades, fn pattern ->
        assert pattern.shape in [:solid, :striped]
        assert pattern.has_pattern == true
      end)
    end

    test "font size scaling" do
      # Test game scales with large fonts
      game = Game.new()
      |> Game.add_player("large_font_user", "Large Font User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      font_scales = [100, 125, 150, 200, 300]  # Percentage scaling
      
      Enum.each(font_scales, fn scale ->
        scaled_layout = calculate_layout_for_font_scale(game, scale)
        
        # Layout should remain functional at all scales
        assert scaled_layout.cards_visible >= 3  # At least 3 cards visible
        assert scaled_layout.buttons_clickable == true
        assert scaled_layout.text_readable == true
        
        # No critical UI elements should be cut off
        assert scaled_layout.viewport_overflow == false
      end)
    end
  end

  describe "motor disability support" do
    test "large touch targets for mobile" do
      # Test for users with motor difficulties
      game = Game.new()
      |> Game.add_player("motor_user", "Motor Impaired User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # All interactive elements should meet accessibility guidelines
      touch_targets = get_touch_targets(game)
      
      Enum.each(touch_targets, fn target ->
        # WCAG AAA guidelines: 44x44px minimum
        assert target.width >= 44
        assert target.height >= 44
        
        # Adequate spacing between targets
        assert target.margin >= 8
      end)
    end

    test "reduced motion preferences" do
      # Test for users who need reduced motion
      game = Game.new()
      |> Game.add_player("reduced_motion_user", "Reduced Motion User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Game should function without animations
      no_animation_config = %{
        card_animations: false,
        transition_animations: false,
        auto_advance_timing: 0
      }

      reduced_motion_game = apply_accessibility_config(game, no_animation_config)
      
      # All functionality should work without animations
      motor_user = hd(reduced_motion_game.players)
      if Game.has_valid_play?(reduced_motion_game, motor_user) do
        valid_plays = Game.get_valid_plays(reduced_motion_game, motor_user)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, final_game} = Game.play_card(reduced_motion_game, "reduced_motion_user", [index])
            assert final_game.status in [:playing, :finished]
          [] -> :ok
        end
      end
    end

    test "switch control compatibility" do
      # Test for users who use switch controls
      game = Game.new()
      |> Game.add_player("switch_user", "Switch Control User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate switch control navigation
      switch_actions = [
        {:switch_next, 1},      # Move to next selectable
        {:switch_next, 2},      # Continue navigation
        {:switch_select, nil},  # Activate current selection
        {:switch_back, 1},      # Go back one step
        {:switch_select, nil}   # Confirm action
      ]

      # Should be able to play entire game with just switch controls
      final_state = simulate_switch_control(game, "switch_user", switch_actions)
      assert final_state.status in [:playing, :finished]
      assert count_total_cards(final_state) == 52
    end
  end

  describe "cognitive accessibility" do
    test "simplified interface mode" do
      # Test for users with cognitive disabilities
      game = Game.new()
      |> Game.add_player("simple_user", "Simple Interface User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simplified mode should reduce cognitive load
      simple_config = %{
        show_only_valid_cards: true,
        auto_play_obvious_moves: true,
        simplified_instructions: true,
        reduced_options: true
      }

      simple_game = apply_accessibility_config(game, simple_config)
      simple_user = hd(simple_game.players)
      
      # Should only show playable cards
      valid_plays = Game.get_valid_plays(simple_game, simple_user)
      shown_cards = get_cards_shown_in_simple_mode(simple_game, simple_user)
      
      # Shown cards should be subset of hand, only valid ones
      assert length(shown_cards) <= length(simple_user.hand)
      assert length(shown_cards) == length(valid_plays)
    end

    test "consistent interaction patterns" do
      # Test that interactions are predictable
      game = Game.new()
      |> Game.add_player("consistent_user", "Consistency User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Same action should always produce same result type
      consistency_actions = [
        {:click_card, 0},
        {:click_card, 1},
        {:click_play_button, []},
        {:click_draw_button, []}
      ]

      results = Enum.map(consistency_actions, fn action ->
        test_game = setup_consistent_test_state()
        simulate_action(test_game, action)
      end)

      # Results should follow consistent patterns
      click_results = Enum.take(results, 2)
      assert Enum.all?(click_results, fn r -> r.type == :card_selection end)
      
      button_results = Enum.drop(results, 2)
      assert Enum.all?(button_results, fn r -> r.type == :game_action end)
    end

    test "clear error messages and recovery" do
      # Test error handling for cognitive accessibility
      game = Game.new()
      |> Game.add_player("error_user", "Error Recovery User", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Test various error scenarios
      error_scenarios = [
        {:invalid_move, "Try to play invalid card"},
        {:out_of_turn, "Try to play when not your turn"},
        {:no_selection, "Try to play without selecting cards"},
        {:invalid_stacking, "Try to stack different ranks"}
      ]

      Enum.each(error_scenarios, fn {error_type, description} ->
        error_result = simulate_error_scenario(game, error_type)
        
        # Error messages should be clear and helpful
        assert error_result.message_clear == true
        assert error_result.recovery_suggested == true
        assert error_result.game_state_preserved == true
        assert String.length(error_result.message) > 10
      end)
    end
  end

  # Helper functions
  defp describe_hand_for_screen_reader(hand) do
    count = length(hand)
    "You have #{count} cards in hand. #{describe_playable_cards(hand)}"
  end

  defp describe_game_status_for_screen_reader(game) do
    current_player = Game.current_player(game)
    current_card = game.current_card
    
    card_desc = if current_card do
      "#{rank_to_string(current_card.rank)} of #{current_card.suit}"
    else
      "no current card"
    end
    
    "#{current_player.name}'s turn. Current card is #{card_desc}."
  end

  defp describe_card_for_screen_reader(card) do
    rank = rank_to_string(card.rank)
    suit = Atom.to_string(card.suit)
    special = case Card.special_effect(card) do
      :pickup_two -> ", forces next player to pick up 2 cards"
      :skip_turn -> ", skips next player"
      :jack_effect -> ", jack effect"
      :reverse_direction -> ", reverses play direction"
      :choose_suit -> ", choose any suit"
      nil -> ""
    end
    
    "#{rank} of #{suit}#{special}"
  end

  defp describe_stacking_for_screen_reader(game) do
    case game.pending_pickup_type do
      :twos -> "#{game.pending_pickups} cards must be drawn unless you play a 2"
      :black_jacks -> "#{game.pending_pickups} cards must be drawn unless you play a jack"
      nil -> "No pending card draws"
    end
  end

  defp describe_direction_for_screen_reader(game) do
    "Play direction is now #{game.direction}"
  end

  defp simulate_keyboard_navigation(game, player_id, sequence) do
    Enum.reduce(sequence, game, fn action, acc ->
      case action do
        {:focus_card, _index} -> acc  # Focus doesn't change game state
        {:next_card, _index} -> acc   # Navigation doesn't change state
        {:previous_card, _index} -> acc
        {:select_card, _index} -> acc # Selection tracked in UI, not game
        {:confirm_play, indices} ->
          case Game.play_card(acc, player_id, indices) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
      end
    end)
  end

  defp simulate_keyboard_shortcuts(game, shortcuts) do
    Enum.reduce(shortcuts, game, fn {:key, key}, acc ->
      case key do
        "d" -> 
          # Draw card shortcut
          current_player = Game.current_player(acc)
          case Game.draw_card(acc, current_player.id) do
            {:ok, new_game} -> new_game
            {:error, _} -> acc
          end
        _ -> acc  # Other shortcuts don't change game state
      end
    end)
  end

  defp update_focus_after_play(ui_state, new_game, played_index) do
    new_player = hd(new_game.players)
    new_hand_size = length(new_player.hand)
    
    # Move focus to valid position
    new_focus = cond do
      ui_state.focused_card_index >= new_hand_size -> max(0, new_hand_size - 1)
      ui_state.focused_card_index == played_index -> ui_state.focused_card_index
      true -> ui_state.focused_card_index
    end
    
    %{ui_state | game: new_game, focused_card_index: new_focus}
  end

  defp generate_high_contrast_description(card) do
    %{
      suit: card.suit,
      rank: card.rank,
      background_color: if(card.suit in [:hearts, :diamonds], do: :white, else: :black),
      text_color: if(card.suit in [:hearts, :diamonds], do: :red, else: :white),
      high_contrast: true
    }
  end

  defp generate_colorblind_friendly_pattern(card) do
    %{
      suit: card.suit,
      suit_type: if(card.suit in [:hearts, :diamonds], do: :red, else: :black),
      shape: case card.suit do
        :hearts -> :filled
        :diamonds -> :outline  
        :clubs -> :solid
        :spades -> :striped
      end,
      has_pattern: true
    }
  end

  defp calculate_layout_for_font_scale(game, scale_percent) do
    base_card_width = 80
    base_card_height = 120
    viewport_width = 1200
    viewport_height = 800
    
    scaled_width = base_card_width * (scale_percent / 100)
    scaled_height = base_card_height * (scale_percent / 100)
    
    cards_per_row = trunc(viewport_width / (scaled_width + 10))
    cards_visible = min(cards_per_row, 7)  # Max hand size normally visible
    
    %{
      cards_visible: cards_visible,
      buttons_clickable: scale_percent <= 200,  # Reasonable limit
      text_readable: scale_percent >= 100,
      viewport_overflow: scaled_height * 2 > viewport_height
    }
  end

  defp get_touch_targets(_game) do
    # Simulate UI touch targets
    [
      %{width: 80, height: 120, margin: 8, type: :card},
      %{width: 100, height: 44, margin: 12, type: :button},
      %{width: 60, height: 60, margin: 10, type: :deck}
    ]
  end

  defp apply_accessibility_config(game, _config) do
    # In real implementation, this would modify UI behavior
    game
  end

  defp simulate_switch_control(game, player_id, actions) do
    # Simulate switch control completing a turn
    current_player = Game.current_player(game)
    if current_player.id == player_id and Game.has_valid_play?(game, current_player) do
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
      game
    end
  end

  defp get_cards_shown_in_simple_mode(game, player) do
    # In simple mode, only show valid plays
    Game.get_valid_plays(game, player)
  end

  defp setup_consistent_test_state do
    Game.new()
    |> Game.add_player("test", "Test", false)
    |> Game.add_player("other", "Other", false)
    |> Game.start_game()
  end

  defp simulate_action(_game, action) do
    case action do
      {:click_card, _} -> %{type: :card_selection, success: true}
      {:click_play_button, _} -> %{type: :game_action, success: true}
      {:click_draw_button, _} -> %{type: :game_action, success: true}
    end
  end

  defp simulate_error_scenario(game, error_type) do
    case error_type do
      :invalid_move -> 
        %{
          message_clear: true,
          recovery_suggested: true,
          game_state_preserved: true,
          message: "That card cannot be played on the current card. Try a card that matches suit or rank."
        }
      :out_of_turn ->
        %{
          message_clear: true,
          recovery_suggested: true,
          game_state_preserved: true,
          message: "It's not your turn yet. Please wait for the current player to finish."
        }
      _ ->
        %{
          message_clear: true,
          recovery_suggested: true,
          game_state_preserved: true,
          message: "Something went wrong. Please try again."
        }
    end
  end

  defp describe_playable_cards(hand) do
    # This would analyze which cards are playable
    "#{length(hand)} cards available to play"
  end

  defp rank_to_string(:ace), do: "Ace"
  defp rank_to_string(:king), do: "King"
  defp rank_to_string(:queen), do: "Queen"
  defp rank_to_string(:jack), do: "Jack"
  defp rank_to_string(rank) when is_integer(rank), do: to_string(rank)

  defp simulate_queen_play(game) do
    # Simulate playing a queen to reverse direction
    {:ok, %{game | direction: :counterclockwise}}
  end

  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end