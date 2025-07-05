defmodule Rachel.AI.EnhancedAIPlayer do
  @moduledoc """
  Enhanced AI player with personality-driven decision making.
  Replaces the basic AI with personality-aware strategic thinking.
  """

  alias Rachel.AI.Personality
  alias Rachel.Games.{Card, Game}

  @type ai_state :: %{
          personality: Personality.personality(),
          game_memory: %{
            cards_seen: [Card.t()],
            opponent_patterns: %{String.t() => map()},
            suit_frequencies: %{atom() => integer()},
            special_cards_played: [atom()],
            game_phase: :early | :mid | :late
          },
          decision_context: %{
            last_moves: [map()],
            threat_level: float(),
            opportunity_score: float()
          }
        }

  @doc """
  Creates a new AI player with the specified personality.
  """
  def new_ai_player(name, personality_type \\ :random) do
    personality =
      case personality_type do
        :random -> Personality.random_personality()
        type -> Personality.get_personality(type)
      end

    %{
      id: generate_ai_id(),
      name: name,
      is_ai: true,
      personality: personality,
      ai_state: %{
        personality: personality,
        game_memory: %{
          cards_seen: [],
          opponent_patterns: %{},
          suit_frequencies: %{hearts: 0, diamonds: 0, clubs: 0, spades: 0},
          special_cards_played: [],
          game_phase: :early
        },
        decision_context: %{
          last_moves: [],
          threat_level: 0.0,
          opportunity_score: 0.0
        }
      }
    }
  end

  @doc """
  Enhanced AI decision making with personality traits.
  """
  def choose_play(game, ai_player) do
    # Update game memory and context
    updated_ai = update_ai_memory(ai_player, game)

    # Analyze current situation
    context = analyze_game_context(game, updated_ai)

    # Get the player struct from the game
    player = Enum.find(game.players, &(&1.id == updated_ai.id))
    
    # Get valid plays
    valid_plays = if player, do: Game.get_valid_plays(game, player), else: []

    case valid_plays do
      [] ->
        # Must draw card
        thinking_time = Personality.get_thinking_time(updated_ai.ai_state.personality, 0.5)
        Process.sleep(thinking_time)
        {:draw_card, updated_ai}

      plays ->
        # Score each play using personality
        scored_plays =
          Enum.map(plays, fn {card, index} ->
            # Convert single card to list for scoring
            cards = [card]
            base_score = calculate_base_score(cards, game, context)

            personality_score =
              Personality.apply_personality_to_score(
                base_score,
                updated_ai.ai_state.personality,
                build_play_context(cards, game, context)
              )

            {{card, index}, personality_score}
          end)

        # Select best play with some randomness for personality
        {_best_card, best_index} = select_play_with_personality(scored_plays, updated_ai.ai_state.personality)

        # Calculate thinking time based on decision complexity
        complexity = calculate_decision_complexity(scored_plays)
        thinking_time = Personality.get_thinking_time(updated_ai.ai_state.personality, complexity)
        Process.sleep(thinking_time)

        {:play_cards, [best_index], updated_ai}
    end
  end

  @doc """
  Gets AI commentary for a move (used by spectator system).
  """
  def get_ai_commentary(ai_player, move_type, context \\ %{}) do
    personality = ai_player.ai_state.personality
    Personality.get_personality_comment(personality, move_type, context)
  end

  @doc """
  Updates AI memory and learning from game events.
  """
  def update_from_game_event(ai_player, event) do
    case event do
      {:card_played, player_id, cards} ->
        update_opponent_patterns(ai_player, player_id, :card_played, %{cards: cards})

      {:card_drawn, player_id, count} ->
        update_opponent_patterns(ai_player, player_id, :card_drawn, %{count: count})

      {:suit_nominated, player_id, suit} ->
        update_opponent_patterns(ai_player, player_id, :suit_nominated, %{suit: suit})

      _ ->
        ai_player
    end
  end

  # Private helper functions

  defp generate_ai_id do
    "ai_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase())
  end

  defp update_ai_memory(ai_player, game) do
    memory = ai_player.ai_state.game_memory

    # Update game phase
    total_cards_in_play = Enum.sum(Enum.map(game.players, &length(&1.hand)))

    game_phase =
      cond do
        total_cards_in_play > 30 -> :early
        total_cards_in_play > 15 -> :mid
        true -> :late
      end

    # Update memory
    updated_memory = %{memory | game_phase: game_phase}

    put_in(ai_player, [:ai_state, :game_memory], updated_memory)
  end

  defp analyze_game_context(game, ai_player) do
    personality = ai_player.ai_state.personality
    memory = ai_player.ai_state.game_memory

    # Calculate threat level
    threat_level = calculate_threat_level(game, ai_player)

    # Calculate opportunity score
    opportunity_score = calculate_opportunity_score(game, ai_player)

    # Determine strategic priorities
    priorities = determine_strategic_priorities(game, personality, memory)

    %{
      threat_level: threat_level,
      opportunity_score: opportunity_score,
      priorities: priorities,
      game_phase: memory.game_phase,
      hand_size: length(get_ai_hand(game, ai_player.id)),
      opponents: get_opponent_info(game, ai_player.id)
    }
  end

  defp calculate_base_score(cards, _game, context) do
    # Basic scoring factors
    hand_reduction_score = length(cards) * 10
    card_value_score = Enum.sum(Enum.map(cards, &get_card_value/1))

    # Special card bonuses
    special_bonus = Enum.sum(Enum.map(cards, &get_special_card_bonus(&1, context)))

    # Defensive considerations
    defensive_score = get_defensive_score(cards, context)

    hand_reduction_score + card_value_score + special_bonus + defensive_score
  end

  defp build_play_context(cards, _game, context) do
    %{
      is_aggressive_play: has_special_cards(cards),
      requires_patience: context.game_phase == :early and length(cards) == 1,
      is_risky: risky_play?(cards, context),
      affects_opponents: affects_other_players(cards),
      is_defensive: defensive_play?(cards, context),
      uses_special_card: has_special_cards(cards),
      controls_suit: changes_suit(cards),
      early_game: context.game_phase == :early,
      hand_size: context.hand_size,
      uses_memory: requires_card_memory(cards),
      affects_multiple_opponents: length(context.opponents) > 1 and affects_other_players(cards)
    }
  end

  defp select_play_with_personality(scored_plays, personality) do
    sorted_plays = Enum.sort_by(scored_plays, &elem(&1, 1), :desc)

    # Add personality-based selection randomness
    case personality.type do
      :chaotic ->
        # Sometimes pick a random play
        if :rand.uniform() < 0.3 do
          {play, _score} = Enum.random(scored_plays)
          play
        else
          {play, _score} = hd(sorted_plays)
          play
        end

      :conservative ->
        # Pick from top 30% but favor safer plays
        top_plays = Enum.take(sorted_plays, max(1, div(length(sorted_plays), 3)))
        {play, _score} = Enum.random(top_plays)
        play

      _ ->
        # Pick best with slight randomness
        if :rand.uniform() < 0.1 and length(sorted_plays) > 1 do
          {play, _score} = Enum.at(sorted_plays, 1)
          play
        else
          {play, _score} = hd(sorted_plays)
          play
        end
    end
  end

  defp calculate_decision_complexity(scored_plays) do
    # Higher complexity when there are many similar-scored options
    scores = Enum.map(scored_plays, &elem(&1, 1))
    score_variance = calculate_variance(scores)

    base_complexity = length(scored_plays) / 10.0
    variance_factor = max(0.5, 2.0 - score_variance / 10.0)

    base_complexity * variance_factor
  end

  defp calculate_variance(scores) do
    if length(scores) <= 1, do: 0.0

    mean = Enum.sum(scores) / length(scores)
    variance = Enum.sum(Enum.map(scores, &:math.pow(&1 - mean, 2))) / length(scores)
    variance
  end

  defp calculate_threat_level(game, ai_player) do
    opponents = get_opponent_info(game, ai_player.id)

    case opponents do
      [] -> 0.0
      _ -> calculate_average_threat(opponents)
    end
  end
  
  defp calculate_average_threat(opponents) do
    total_threat = opponents
      |> Enum.map(&calculate_opponent_threat/1)
      |> Enum.sum()
      
    total_threat / length(opponents)
  end
  
  defp calculate_opponent_threat(opponent) do
    case opponent.hand_size do
      size when size <= 2 -> 0.8
      size when size <= 4 -> 0.5
      size when size <= 6 -> 0.3
      _ -> 0.1
    end
  end

  defp calculate_opportunity_score(game, ai_player) do
    hand = get_ai_hand(game, ai_player.id)

    # Score based on special cards and hand composition
    special_card_count = Enum.count(hand, &special_card?/1)
    hand_size_factor = max(0.1, 1.0 - length(hand) / 15.0)

    special_card_count * 0.3 + hand_size_factor * 0.7
  end

  defp determine_strategic_priorities(_game, personality, _memory) do
    base_priorities = %{
      hand_reduction: 0.5,
      opponent_disruption: 0.3,
      suit_control: 0.2,
      special_card_usage: 0.4,
      defense: 0.3
    }

    # Adjust based on personality
    case personality.type do
      :aggressive ->
        %{base_priorities | opponent_disruption: 0.8, special_card_usage: 0.9, defense: 0.1}

      :conservative ->
        %{base_priorities | defense: 0.8, hand_reduction: 0.7, opponent_disruption: 0.1}

      :strategic ->
        %{base_priorities | suit_control: 0.8, special_card_usage: 0.7}

      _ ->
        base_priorities
    end
  end

  defp get_ai_hand(game, ai_id) do
    case Enum.find(game.players, &(&1.id == ai_id)) do
      nil -> []
      player -> player.hand
    end
  end

  defp get_opponent_info(game, ai_id) do
    game.players
    |> Enum.filter(&(&1.id != ai_id))
    |> Enum.map(fn player ->
      %{
        id: player.id,
        name: player.name,
        hand_size: length(player.hand),
        is_ai: player.is_ai
      }
    end)
  end

  defp update_opponent_patterns(ai_player, player_id, action, data) do
    if player_id != ai_player.id do
      patterns = ai_player.ai_state.game_memory.opponent_patterns
      player_pattern = Map.get(patterns, player_id, %{actions: [], tendencies: %{}})

      updated_pattern = %{
        player_pattern
        | actions: [
            %{action: action, data: data, timestamp: DateTime.utc_now()} | player_pattern.actions
          ]
      }

      updated_patterns = Map.put(patterns, player_id, updated_pattern)
      put_in(ai_player, [:ai_state, :game_memory, :opponent_patterns], updated_patterns)
    else
      ai_player
    end
  end

  # Card evaluation helpers

  defp get_card_value(%Card{rank: rank}) do
    case rank do
      :ace -> 15
      :king -> 13
      :queen -> 12
      :jack -> 11
      n when is_integer(n) -> n
      _ -> 5
    end
  end

  defp get_special_card_bonus(%Card{rank: rank}, context) do
    base_bonuses = %{
      2 => {10, 20, 0.5},      # base, threat_bonus, threat_threshold
      7 => {8, 15, 0.3},
      :jack => {25, 25, 1.0},  # Always 25
      :queen => {12, 18, 0.6}, # Based on opportunity score instead
      :ace => {20, 20, 1.0}    # Always 20
    }
    
    case Map.get(base_bonuses, rank) do
      {base, threat_bonus, threshold} ->
        score_to_check = if rank == :queen, do: context.opportunity_score, else: context.threat_level
        if score_to_check > threshold, do: threat_bonus, else: base
        
      nil ->
        0
    end
  end

  defp get_defensive_score(cards, context) do
    if context.threat_level > 0.6 do
      # Prioritize defensive special cards when under threat
      cards
      |> Enum.map(&score_defensive_card/1)
      |> Enum.sum()
    else
      0
    end
  end
  
  defp score_defensive_card(card) do
    case card.rank do
      2 -> 15      # Force pickup
      7 -> 10      # Skip
      :jack -> 
        if card.suit in [:clubs, :spades], do: 25, else: -5
      _ -> 0
    end
  end

  defp has_special_cards(cards) do
    Enum.any?(cards, &special_card?/1)
  end

  defp special_card?(%Card{rank: rank}) do
    rank in [2, 7, :jack, :queen, :ace]
  end

  defp affects_other_players(cards) do
    Enum.any?(cards, fn card ->
      card.rank in [2, 7, :jack, :queen]
    end)
  end

  defp risky_play?(cards, context) do
    # Playing special cards early or when not under threat could be risky
    has_special_cards(cards) and context.game_phase == :early and context.threat_level < 0.3
  end

  defp defensive_play?(cards, context) do
    context.threat_level > 0.5 and
      Enum.any?(cards, fn card ->
        card.rank in [2, 7, :jack]
      end)
  end

  defp changes_suit(cards) do
    Enum.any?(cards, &(&1.rank == :ace))
  end

  defp requires_card_memory(cards) do
    # Strategic plays that benefit from knowing what cards have been played
    Enum.any?(cards, &(&1.rank in [:ace, :queen])) or length(cards) > 2
  end
end
