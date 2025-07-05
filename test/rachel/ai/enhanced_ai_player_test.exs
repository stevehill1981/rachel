defmodule Rachel.AI.EnhancedAIPlayerTest do
  use ExUnit.Case, async: true

  alias Rachel.AI.EnhancedAIPlayer

  describe "new_ai_player/2" do
    test "creates AI player with random personality" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test AI")

      assert ai_player.name == "Test AI"
      assert ai_player.is_ai == true
      assert String.starts_with?(ai_player.id, "ai_")
      assert is_map(ai_player.ai_state.personality)
      assert Map.has_key?(ai_player.ai_state.personality, :type)
      assert ai_player.ai_state.game_memory.game_phase == :early
    end

    test "creates AI player with specific personality" do
      ai_player = EnhancedAIPlayer.new_ai_player("Aggressive AI", :aggressive)

      assert ai_player.name == "Aggressive AI"
      assert ai_player.ai_state.personality.type == :aggressive
    end

    test "generates unique AI IDs" do
      ai1 = EnhancedAIPlayer.new_ai_player("AI 1")
      ai2 = EnhancedAIPlayer.new_ai_player("AI 2")

      assert ai1.id != ai2.id
      assert String.length(ai1.id) > 3
      assert String.length(ai2.id) > 3
    end

    test "initializes AI state correctly" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test AI")

      assert ai_player.ai_state.game_memory.cards_seen == []
      assert ai_player.ai_state.game_memory.opponent_patterns == %{}
      assert ai_player.ai_state.game_memory.suit_frequencies == %{
               hearts: 0,
               diamonds: 0,
               clubs: 0,
               spades: 0
             }
      assert ai_player.ai_state.game_memory.special_cards_played == []
      assert ai_player.ai_state.decision_context.last_moves == []
      assert ai_player.ai_state.decision_context.threat_level == 0.0
      assert ai_player.ai_state.decision_context.opportunity_score == 0.0
    end

    test "creates different personality types" do
      aggressive = EnhancedAIPlayer.new_ai_player("Aggressive", :aggressive)
      conservative = EnhancedAIPlayer.new_ai_player("Conservative", :conservative)
      strategic = EnhancedAIPlayer.new_ai_player("Strategic", :strategic)
      chaotic = EnhancedAIPlayer.new_ai_player("Chaotic", :chaotic)

      assert aggressive.ai_state.personality.type == :aggressive
      assert conservative.ai_state.personality.type == :conservative
      assert strategic.ai_state.personality.type == :strategic
      assert chaotic.ai_state.personality.type == :chaotic
    end

    test "random personality selection creates valid personality" do
      ai_player = EnhancedAIPlayer.new_ai_player("Random AI", :random)
      
      valid_types = [:aggressive, :conservative, :strategic, :chaotic, :adaptive, :bluffer]
      assert ai_player.ai_state.personality.type in valid_types
    end
  end

  describe "get_ai_commentary/3" do
    test "returns commentary for aggressive personality" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test AI", :aggressive)
      
      commentary = EnhancedAIPlayer.get_ai_commentary(ai_player, :special_card, %{})
      
      assert is_binary(commentary)
      assert String.length(commentary) > 0
    end

    test "returns commentary for strategic personality" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test AI", :strategic)
      
      commentary = EnhancedAIPlayer.get_ai_commentary(ai_player, :calculated_move)
      
      assert is_binary(commentary)
      assert String.length(commentary) > 0
    end

    test "returns generic commentary for card play" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test AI", :strategic)
      
      commentary = EnhancedAIPlayer.get_ai_commentary(ai_player, :card_play)
      
      assert is_binary(commentary)
      assert String.length(commentary) > 0
    end

    test "handles different personality types" do
      types = [:aggressive, :conservative, :strategic, :chaotic, :adaptive, :bluffer]
      
      for personality_type <- types do
        ai_player = EnhancedAIPlayer.new_ai_player("Test", personality_type)
        commentary = EnhancedAIPlayer.get_ai_commentary(ai_player, :card_play)
        
        assert is_binary(commentary)
        assert String.length(commentary) > 0
      end
    end
  end

  describe "update_from_game_event/2" do
    setup do
      ai_player = EnhancedAIPlayer.new_ai_player("Test AI")
      {:ok, ai_player: ai_player}
    end

    test "updates patterns when other player plays cards", %{ai_player: ai_player} do
      event = {:card_played, "other_player", [%{suit: :hearts, rank: 5}]}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      assert Map.has_key?(updated_ai.ai_state.game_memory.opponent_patterns, "other_player")
      pattern = updated_ai.ai_state.game_memory.opponent_patterns["other_player"]
      assert length(pattern.actions) == 1
      assert hd(pattern.actions).action == :card_played
    end

    test "updates patterns when other player draws cards", %{ai_player: ai_player} do
      event = {:card_drawn, "other_player", 2}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      pattern = updated_ai.ai_state.game_memory.opponent_patterns["other_player"]
      assert hd(pattern.actions).action == :card_drawn
      assert hd(pattern.actions).data.count == 2
    end

    test "updates patterns when other player nominates suit", %{ai_player: ai_player} do
      event = {:suit_nominated, "other_player", :spades}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      pattern = updated_ai.ai_state.game_memory.opponent_patterns["other_player"]
      assert hd(pattern.actions).action == :suit_nominated
      assert hd(pattern.actions).data.suit == :spades
    end

    test "ignores events from self", %{ai_player: ai_player} do
      event = {:card_played, ai_player.id, [%{suit: :hearts, rank: 5}]}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      assert updated_ai.ai_state.game_memory.opponent_patterns == %{}
    end

    test "ignores unknown events", %{ai_player: ai_player} do
      event = {:unknown_event, "other_player", %{}}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      assert updated_ai == ai_player
    end

    test "tracks multiple events from same player", %{ai_player: ai_player} do
      event1 = {:card_played, "other_player", [%{suit: :hearts, rank: 5}]}
      event2 = {:card_drawn, "other_player", 1}
      
      updated_ai = 
        ai_player
        |> EnhancedAIPlayer.update_from_game_event(event1)
        |> EnhancedAIPlayer.update_from_game_event(event2)
      
      pattern = updated_ai.ai_state.game_memory.opponent_patterns["other_player"]
      assert length(pattern.actions) == 2
      # Events should be in reverse chronological order (newest first)
      assert hd(pattern.actions).action == :card_drawn
      assert hd(tl(pattern.actions)).action == :card_played
    end

    test "tracks multiple different players", %{ai_player: ai_player} do
      event1 = {:card_played, "player_1", [%{suit: :hearts, rank: 5}]}
      event2 = {:card_drawn, "player_2", 1}
      
      updated_ai = 
        ai_player
        |> EnhancedAIPlayer.update_from_game_event(event1)
        |> EnhancedAIPlayer.update_from_game_event(event2)
      
      patterns = updated_ai.ai_state.game_memory.opponent_patterns
      assert Map.has_key?(patterns, "player_1")
      assert Map.has_key?(patterns, "player_2")
      assert length(patterns["player_1"].actions) == 1
      assert length(patterns["player_2"].actions) == 1
    end
  end

  describe "private helper function coverage via public interface" do
    test "generate_ai_id creates valid IDs" do
      # Test via new_ai_player which calls generate_ai_id
      ai1 = EnhancedAIPlayer.new_ai_player("Test 1")
      ai2 = EnhancedAIPlayer.new_ai_player("Test 2")
      
      # Should start with ai_ prefix
      assert String.starts_with?(ai1.id, "ai_")
      assert String.starts_with?(ai2.id, "ai_")
      
      # Should be different
      assert ai1.id != ai2.id
      
      # Should be reasonable length (more than just "ai_")
      assert String.length(ai1.id) > 10
      assert String.length(ai2.id) > 10
    end

    test "personality initialization includes all required fields" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test", :strategic)
      personality = ai_player.ai_state.personality
      
      # Test that personality has required structure
      assert Map.has_key?(personality, :type)
      assert Map.has_key?(personality, :name)
      assert Map.has_key?(personality, :description)
      assert Map.has_key?(personality, :traits)
      assert Map.has_key?(personality, :decision_weights)
      assert Map.has_key?(personality, :quirks)
      assert Map.has_key?(personality, :difficulty_modifier)
      
      # Test traits structure
      traits = personality.traits
      assert Map.has_key?(traits, :aggression)
      assert Map.has_key?(traits, :patience)
      assert Map.has_key?(traits, :risk_tolerance)
      assert Map.has_key?(traits, :card_counting)
      assert Map.has_key?(traits, :bluffing)
      assert Map.has_key?(traits, :adaptability)
      assert Map.has_key?(traits, :special_focus)
      
      # Test decision weights structure
      weights = personality.decision_weights
      assert Map.has_key?(weights, :card_value)
      assert Map.has_key?(weights, :hand_size)
      assert Map.has_key?(weights, :opponent_impact)
      assert Map.has_key?(weights, :self_protection)
      assert Map.has_key?(weights, :special_effects)
      assert Map.has_key?(weights, :suit_control)
    end

    test "AI state initialization includes all memory structures" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test")
      memory = ai_player.ai_state.game_memory
      context = ai_player.ai_state.decision_context
      
      # Game memory should have all required fields
      assert Map.has_key?(memory, :cards_seen)
      assert Map.has_key?(memory, :opponent_patterns)
      assert Map.has_key?(memory, :suit_frequencies)
      assert Map.has_key?(memory, :special_cards_played)
      assert Map.has_key?(memory, :game_phase)
      
      # Decision context should have all required fields
      assert Map.has_key?(context, :last_moves)
      assert Map.has_key?(context, :threat_level)
      assert Map.has_key?(context, :opportunity_score)
      
      # Suit frequencies should include all suits
      freq = memory.suit_frequencies
      assert Map.has_key?(freq, :hearts)
      assert Map.has_key?(freq, :diamonds)
      assert Map.has_key?(freq, :clubs)
      assert Map.has_key?(freq, :spades)
    end

    test "event tracking preserves data structure" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test")
      
      # Test complex event data preservation
      complex_event = {:card_played, "other_player", [
        %{suit: :hearts, rank: :king},
        %{suit: :spades, rank: 5}
      ]}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, complex_event)
      
      pattern = updated_ai.ai_state.game_memory.opponent_patterns["other_player"]
      action = hd(pattern.actions)
      
      assert action.action == :card_played
      assert length(action.data.cards) == 2
      assert Enum.any?(action.data.cards, &(&1.suit == :hearts and &1.rank == :king))
      assert Enum.any?(action.data.cards, &(&1.suit == :spades and &1.rank == 5))
      assert %DateTime{} = action.timestamp
    end
  end

  describe "edge cases and error handling" do
    test "handles empty player ID in events" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test")
      event = {:card_played, "", [%{suit: :hearts, rank: 5}]}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      # Should track empty string as a player ID
      assert Map.has_key?(updated_ai.ai_state.game_memory.opponent_patterns, "")
    end

    test "handles nil data in events" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test")
      event = {:card_played, "other_player", nil}
      
      updated_ai = EnhancedAIPlayer.update_from_game_event(ai_player, event)
      
      pattern = updated_ai.ai_state.game_memory.opponent_patterns["other_player"]
      assert hd(pattern.actions).data.cards == nil
    end

    test "preserves existing patterns when adding new ones" do
      ai_player = EnhancedAIPlayer.new_ai_player("Test")
      
      # Add initial pattern for player 1
      event1 = {:card_played, "player_1", [%{suit: :hearts, rank: 5}]}
      ai_with_p1 = EnhancedAIPlayer.update_from_game_event(ai_player, event1)
      
      # Add pattern for player 2
      event2 = {:card_drawn, "player_2", 3}
      ai_with_both = EnhancedAIPlayer.update_from_game_event(ai_with_p1, event2)
      
      # Both patterns should exist
      patterns = ai_with_both.ai_state.game_memory.opponent_patterns
      assert Map.has_key?(patterns, "player_1")
      assert Map.has_key?(patterns, "player_2")
      
      # Player 1 pattern should be unchanged
      p1_action = hd(patterns["player_1"].actions)
      assert p1_action.action == :card_played
      
      # Player 2 pattern should be new
      p2_action = hd(patterns["player_2"].actions)
      assert p2_action.action == :card_drawn
    end
  end
end