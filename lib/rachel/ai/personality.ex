defmodule Rachel.AI.Personality do
  @moduledoc """
  Defines AI personality traits and behaviors for different playing styles.
  """

  @type personality_type ::
          :aggressive | :conservative | :strategic | :chaotic | :adaptive | :bluffer

  @type personality :: %{
          type: personality_type(),
          name: String.t(),
          description: String.t(),
          traits: %{
            # 0.0-1.0: How likely to play risky moves
            aggression: float(),
            # 0.0-1.0: How likely to hold cards for better opportunities
            patience: float(),
            # 0.0-1.0: Willingness to take chances
            risk_tolerance: float(),
            # 0.0-1.0: Memory and tracking ability
            card_counting: float(),
            # 0.0-1.0: Tendency to mislead opponents
            bluffing: float(),
            # 0.0-1.0: How well they adjust to game state
            adaptability: float(),
            # 0.0-1.0: Priority given to special cards
            special_focus: float()
          },
          decision_weights: %{
            # Weight given to card rank/suit
            card_value: float(),
            # Weight given to reducing hand size
            hand_size: float(),
            # Weight given to affecting opponents
            opponent_impact: float(),
            # Weight given to defensive plays
            self_protection: float(),
            # Weight given to using special cards
            special_effects: float(),
            # Weight given to controlling suit changes
            suit_control: float()
          },
          # Special behaviors unique to this personality
          quirks: [atom()],
          # Multiplier for thinking time and mistakes
          difficulty_modifier: float()
        }

  @doc """
  Gets all available AI personalities.
  """
  def all_personalities do
    [
      aggressive_annie(),
      conservative_charlie(),
      strategic_sam(),
      chaotic_casey(),
      adaptive_alex(),
      bluffer_blake()
    ]
  end

  @doc """
  Gets a personality by type.
  """
  def get_personality(type)
      when type in [:aggressive, :conservative, :strategic, :chaotic, :adaptive, :bluffer] do
    case type do
      :aggressive -> aggressive_annie()
      :conservative -> conservative_charlie()
      :strategic -> strategic_sam()
      :chaotic -> chaotic_casey()
      :adaptive -> adaptive_alex()
      :bluffer -> bluffer_blake()
    end
  end

  @doc """
  Gets a random personality.
  """
  def random_personality do
    all_personalities() |> Enum.random()
  end

  @doc """
  Aggressive Annie - Plays aggressively, loves special cards, takes risks
  """
  def aggressive_annie do
    %{
      type: :aggressive,
      name: "Aggressive Annie",
      description:
        "Plays boldly with special cards and takes calculated risks to dominate the game",
      traits: %{
        aggression: 0.9,
        patience: 0.2,
        risk_tolerance: 0.8,
        card_counting: 0.6,
        bluffing: 0.4,
        adaptability: 0.5,
        special_focus: 0.9
      },
      decision_weights: %{
        card_value: 0.6,
        hand_size: 0.8,
        opponent_impact: 0.9,
        self_protection: 0.3,
        special_effects: 0.9,
        suit_control: 0.7
      },
      quirks: [:early_special_cards, :risky_suit_changes, :aggressive_stacking],
      difficulty_modifier: 0.8
    }
  end

  @doc """
  Conservative Charlie - Plays safely, waits for perfect opportunities
  """
  def conservative_charlie do
    %{
      type: :conservative,
      name: "Conservative Charlie",
      description: "Plays it safe, waits for the perfect moment, and avoids unnecessary risks",
      traits: %{
        aggression: 0.2,
        patience: 0.9,
        risk_tolerance: 0.3,
        card_counting: 0.8,
        bluffing: 0.1,
        adaptability: 0.4,
        special_focus: 0.4
      },
      decision_weights: %{
        card_value: 0.8,
        hand_size: 0.6,
        opponent_impact: 0.4,
        self_protection: 0.9,
        special_effects: 0.5,
        suit_control: 0.6
      },
      quirks: [:hoard_special_cards, :defensive_play, :perfect_timing],
      difficulty_modifier: 1.2
    }
  end

  @doc """
  Strategic Sam - Calculates moves carefully, excellent memory
  """
  def strategic_sam do
    %{
      type: :strategic,
      name: "Strategic Sam",
      description: "Thinks several moves ahead with excellent card memory and strategic planning",
      traits: %{
        aggression: 0.5,
        patience: 0.7,
        risk_tolerance: 0.4,
        card_counting: 0.95,
        bluffing: 0.3,
        adaptability: 0.8,
        special_focus: 0.7
      },
      decision_weights: %{
        card_value: 0.9,
        hand_size: 0.7,
        opponent_impact: 0.8,
        self_protection: 0.7,
        special_effects: 0.8,
        suit_control: 0.9
      },
      quirks: [:card_counting, :future_planning, :optimal_sequences],
      difficulty_modifier: 1.0
    }
  end

  @doc """
  Chaotic Casey - Unpredictable, random plays, keeps opponents guessing
  """
  def chaotic_casey do
    %{
      type: :chaotic,
      name: "Chaotic Casey",
      description: "Unpredictable and chaotic, making random moves that keep opponents guessing",
      traits: %{
        aggression: 0.7,
        patience: 0.3,
        risk_tolerance: 0.9,
        card_counting: 0.3,
        bluffing: 0.8,
        adaptability: 0.6,
        special_focus: 0.6
      },
      decision_weights: %{
        card_value: 0.4,
        hand_size: 0.5,
        opponent_impact: 0.7,
        self_protection: 0.2,
        special_effects: 0.8,
        suit_control: 0.5
      },
      quirks: [:random_plays, :unexpected_moves, :chaos_creation],
      difficulty_modifier: 0.6
    }
  end

  @doc """
  Adaptive Alex - Learns from the game, adjusts strategy dynamically
  """
  def adaptive_alex do
    %{
      type: :adaptive,
      name: "Adaptive Alex",
      description: "Learns from the game flow and adapts strategy based on opponents' behavior",
      traits: %{
        aggression: 0.6,
        patience: 0.6,
        risk_tolerance: 0.5,
        card_counting: 0.7,
        bluffing: 0.5,
        adaptability: 0.95,
        special_focus: 0.6
      },
      decision_weights: %{
        card_value: 0.7,
        hand_size: 0.7,
        opponent_impact: 0.7,
        self_protection: 0.6,
        special_effects: 0.7,
        suit_control: 0.7
      },
      quirks: [:opponent_modeling, :strategy_switching, :learning_patterns],
      difficulty_modifier: 1.1
    }
  end

  @doc """
  Bluffer Blake - Master of deception, psychological warfare
  """
  def bluffer_blake do
    %{
      type: :bluffer,
      name: "Bluffer Blake",
      description: "Master of psychological warfare who uses misdirection and bluffing tactics",
      traits: %{
        aggression: 0.4,
        patience: 0.8,
        risk_tolerance: 0.6,
        card_counting: 0.6,
        bluffing: 0.95,
        adaptability: 0.7,
        special_focus: 0.5
      },
      decision_weights: %{
        card_value: 0.5,
        hand_size: 0.4,
        opponent_impact: 0.9,
        self_protection: 0.5,
        special_effects: 0.6,
        suit_control: 0.8
      },
      quirks: [:fake_tells, :psychological_warfare, :misdirection],
      difficulty_modifier: 1.0
    }
  end

  @doc """
  Applies personality traits to modify a base decision score.
  """
  def apply_personality_to_score(score, personality, play_context) do
    base_score = score

    # Apply trait-based modifications
    trait_modifier = calculate_trait_modifier(personality, play_context)
    weight_modifier = calculate_weight_modifier(personality, play_context)
    quirk_modifier = calculate_quirk_modifier(personality, play_context)

    modified_score = base_score * trait_modifier * weight_modifier + quirk_modifier

    # Add some personality-based randomness
    randomness = get_randomness_factor(personality)
    random_adjustment = (:rand.uniform() - 0.5) * randomness * 10

    Float.round(modified_score + random_adjustment, 2)
  end

  @doc """
  Gets personality-specific commentary for moves.
  """
  def get_personality_comment(personality, move_type, context \\ %{}) do
    case {personality.type, move_type} do
      {:aggressive, :special_card} ->
        Enum.random([
          "#{personality.name} strikes with authority!",
          "No holding back - full aggression!",
          "#{personality.name} goes for the jugular!",
          "Time to show some dominance!"
        ])

      {:conservative, :safe_play} ->
        Enum.random([
          "#{personality.name} plays it safe and steady",
          "Patience is a virtue",
          "#{personality.name} waits for the perfect moment",
          "Calculated and careful as always"
        ])

      {:strategic, :calculated_move} ->
        Enum.random([
          "#{personality.name} executes a calculated strategy",
          "Every move has been planned three steps ahead",
          "#{personality.name} demonstrates tactical brilliance",
          "Perfect strategic positioning"
        ])

      {:chaotic, :random_play} ->
        Enum.random([
          "#{personality.name} throws caution to the wind!",
          "Who needs strategy when you have chaos?",
          "#{personality.name} keeps everyone guessing",
          "Completely unpredictable move!"
        ])

      {:adaptive, :smart_adjustment} ->
        Enum.random([
          "#{personality.name} adapts to the changing game",
          "Learning and evolving in real-time",
          "#{personality.name} adjusts the strategy perfectly",
          "Adaptive intelligence at work"
        ])

      {:bluffer, :deceptive_play} ->
        Enum.random([
          "#{personality.name} might be bluffing... or not",
          "What's the real strategy here?",
          "#{personality.name} plays mind games",
          "Is this part of a bigger deception?"
        ])

      {_, :card_play} ->
        get_generic_comment(personality, context)
    end
  end

  @doc """
  Determines thinking time based on personality.
  """
  def get_thinking_time(personality, decision_complexity \\ 1.0) do
    # 1 second base
    base_time = 1000

    # Personality modifier
    time_modifier = personality.difficulty_modifier

    # Complexity modifier
    complexity_factor = decision_complexity

    # Trait influences
    patience_factor = personality.traits.patience * 0.5 + 0.5
    adaptability_factor = (1.0 - personality.traits.adaptability) * 0.3 + 0.7

    total_time =
      base_time * time_modifier * complexity_factor * patience_factor * adaptability_factor

    # Add some randomness
    # 0.8 to 1.2 multiplier
    randomness = :rand.uniform() * 0.4 + 0.8

    round(total_time * randomness)
  end

  # Private helper functions

  defp calculate_trait_modifier(personality, context) do
    # Base modifier from traits
    aggression_bonus =
      if context[:is_aggressive_play], do: personality.traits.aggression * 0.3, else: 0

    patience_bonus =
      if context[:requires_patience], do: personality.traits.patience * 0.2, else: 0

    risk_penalty =
      if context[:is_risky] and personality.traits.risk_tolerance < 0.5, do: -0.3, else: 0

    1.0 + aggression_bonus + patience_bonus + risk_penalty
  end

  defp calculate_weight_modifier(personality, context) do
    weights = personality.decision_weights

    modifier = 1.0

    modifier =
      if context[:affects_opponents] do
        modifier + (weights.opponent_impact - 0.5) * 0.4
      else
        modifier
      end

    modifier =
      if context[:is_defensive] do
        modifier + (weights.self_protection - 0.5) * 0.3
      else
        modifier
      end

    modifier =
      if context[:uses_special_card] do
        modifier + (weights.special_effects - 0.5) * 0.5
      else
        modifier
      end

    modifier =
      if context[:controls_suit] do
        modifier + (weights.suit_control - 0.5) * 0.3
      else
        modifier
      end

    modifier
  end

  defp calculate_quirk_modifier(personality, context) do
    quirks = personality.quirks
    modifier = 0

    # Apply quirk-specific bonuses
    modifier =
      if :early_special_cards in quirks and context[:early_game] and context[:uses_special_card] do
        modifier + 15
      else
        modifier
      end

    modifier =
      if :hoard_special_cards in quirks and context[:uses_special_card] and context[:hand_size] > 5 do
        modifier - 10
      else
        modifier
      end

    modifier =
      if :random_plays in quirks do
        modifier + (:rand.uniform() - 0.5) * 20
      else
        modifier
      end

    modifier =
      if :card_counting in quirks and context[:uses_memory] do
        modifier + 10
      else
        modifier
      end

    modifier =
      if :psychological_warfare in quirks and context[:affects_multiple_opponents] do
        modifier + 8
      else
        modifier
      end

    modifier
  end

  defp get_randomness_factor(personality) do
    case personality.type do
      :chaotic -> 0.8
      :aggressive -> 0.4
      :bluffer -> 0.3
      :adaptive -> 0.2
      :strategic -> 0.1
      :conservative -> 0.15
    end
  end

  defp get_generic_comment(personality, _context) do
    case personality.type do
      :aggressive -> "#{personality.name} makes a bold move!"
      :conservative -> "#{personality.name} plays cautiously"
      :strategic -> "#{personality.name} thinks it through"
      :chaotic -> "#{personality.name} does something unexpected"
      :adaptive -> "#{personality.name} adjusts the approach"
      :bluffer -> "#{personality.name} makes a mysterious play"
    end
  end
end
