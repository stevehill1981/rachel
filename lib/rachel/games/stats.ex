defmodule Rachel.Games.Stats do
  @moduledoc """
  Game statistics tracking and scoring system.
  """

  alias Rachel.Games.{Card, Game}

  @type player_stats :: %{
          games_played: integer(),
          games_won: integer(),
          total_cards_played: integer(),
          total_cards_drawn: integer(),
          special_cards_played: integer(),
          average_finish_position: float(),
          quickest_win_turns: integer() | nil,
          longest_game_turns: integer()
        }

  @type game_stats :: %{
          total_turns: integer(),
          total_cards_played: integer(),
          total_cards_drawn: integer(),
          special_effects_triggered: integer(),
          direction_changes: integer(),
          suit_nominations: integer(),
          winner_id: String.t() | nil,
          finish_positions: [String.t()],
          game_duration_seconds: integer() | nil
        }

  @type t :: %__MODULE__{
          player_stats: %{String.t() => player_stats()},
          game_stats: game_stats(),
          start_time: DateTime.t()
        }

  defstruct player_stats: %{},
            game_stats: %{
              total_turns: 0,
              total_cards_played: 0,
              total_cards_drawn: 0,
              special_effects_triggered: 0,
              direction_changes: 0,
              suit_nominations: 0,
              winner_id: nil,
              finish_positions: [],
              game_duration_seconds: nil
            },
            start_time: nil

  @spec new([String.t()]) :: t()
  def new(player_ids) do
    start_time = DateTime.utc_now()

    player_stats =
      player_ids
      |> Enum.map(fn id ->
        {id,
         %{
           games_played: 1,
           games_won: 0,
           total_cards_played: 0,
           total_cards_drawn: 0,
           special_cards_played: 0,
           average_finish_position: 0.0,
           quickest_win_turns: nil,
           longest_game_turns: 0
         }}
      end)
      |> Map.new()

    %__MODULE__{
      player_stats: player_stats,
      start_time: start_time
    }
  end

  @spec record_card_played(t(), String.t(), [Card.t()]) :: t()
  def record_card_played(%__MODULE__{} = stats, player_id, cards) when is_list(cards) do
    # Return unchanged stats if player doesn't exist
    if Map.has_key?(stats.player_stats, player_id) do
      card_count = length(cards)
      special_count = Enum.count(cards, &has_special_effect?/1)

      updated_player_stats =
        Map.update!(stats.player_stats, player_id, fn player_stats ->
          player_stats
          |> Map.update!(:total_cards_played, &(&1 + card_count))
          |> Map.update!(:special_cards_played, &(&1 + special_count))
        end)

      updated_game_stats =
        stats.game_stats
        |> Map.update!(:total_cards_played, &(&1 + card_count))
        |> Map.update!(:special_effects_triggered, &(&1 + special_count))

      %{stats | player_stats: updated_player_stats, game_stats: updated_game_stats}
    else
      stats
    end
  end

  @spec record_card_drawn(t(), String.t(), integer()) :: t()
  def record_card_drawn(%__MODULE__{} = stats, player_id, card_count) do
    # Return unchanged stats if player doesn't exist
    if Map.has_key?(stats.player_stats, player_id) do
      updated_player_stats =
        Map.update!(stats.player_stats, player_id, fn player_stats ->
          Map.update!(player_stats, :total_cards_drawn, &(&1 + card_count))
        end)

      updated_game_stats =
        Map.update!(stats.game_stats, :total_cards_drawn, &(&1 + card_count))

      %{stats | player_stats: updated_player_stats, game_stats: updated_game_stats}
    else
      stats
    end
  end

  @spec record_turn_advance(t()) :: t()
  def record_turn_advance(%__MODULE__{} = stats) do
    updated_game_stats =
      Map.update!(stats.game_stats, :total_turns, &(&1 + 1))

    %{stats | game_stats: updated_game_stats}
  end

  @spec record_direction_change(t()) :: t()
  def record_direction_change(%__MODULE__{} = stats) do
    updated_game_stats =
      Map.update!(stats.game_stats, :direction_changes, &(&1 + 1))

    %{stats | game_stats: updated_game_stats}
  end

  @spec record_suit_nomination(t()) :: t()
  def record_suit_nomination(%__MODULE__{} = stats) do
    updated_game_stats =
      Map.update!(stats.game_stats, :suit_nominations, &(&1 + 1))

    %{stats | game_stats: updated_game_stats}
  end

  @spec record_winner(t(), String.t()) :: t()
  def record_winner(%__MODULE__{} = stats, winner_id) do
    updated_game_stats = calculate_game_duration_if_first_winner(stats)
    position = length(stats.game_stats.finish_positions) + 1

    updated_player_stats = update_player_stats_for_winner(stats, winner_id, position)
    final_game_stats = finalize_game_stats_with_winner(updated_game_stats, winner_id)

    %{stats | player_stats: updated_player_stats, game_stats: final_game_stats}
  end

  defp calculate_game_duration_if_first_winner(stats) do
    if stats.game_stats.winner_id == nil do
      end_time = DateTime.utc_now()
      duration = DateTime.diff(end_time, stats.start_time)
      Map.put(stats.game_stats, :game_duration_seconds, duration)
    else
      stats.game_stats
    end
  end

  defp update_player_stats_for_winner(stats, winner_id, position) do
    Map.update(stats.player_stats, winner_id, nil, fn player_stats ->
      if player_stats do
        update_winner_player_stats(player_stats, stats.game_stats.total_turns, position)
      else
        player_stats
      end
    end)
  end

  defp update_winner_player_stats(player_stats, total_turns, position) do
    is_first_place = position == 1

    player_stats
    |> Map.put(:position, position)
    |> Map.update!(:games_won, fn wins -> if is_first_place, do: wins + 1, else: wins end)
    |> update_quickest_win_turns(total_turns, is_first_place)
    |> Map.update!(:longest_game_turns, &max(&1, total_turns))
  end

  defp update_quickest_win_turns(player_stats, total_turns, is_first_place) do
    Map.update!(player_stats, :quickest_win_turns, fn
      nil -> if is_first_place, do: total_turns, else: nil
      current -> if is_first_place, do: min(current, total_turns), else: current
    end)
  end

  defp finalize_game_stats_with_winner(game_stats, winner_id) do
    game_stats
    |> Map.update!(:finish_positions, &(&1 ++ [winner_id]))
    |> Map.update(:winner_id, winner_id, fn existing -> existing || winner_id end)
  end

  @spec record_finish_position(t(), String.t()) :: t()
  def record_finish_position(%__MODULE__{} = stats, player_id) do
    updated_positions = stats.game_stats.finish_positions ++ [player_id]
    updated_game_stats = Map.put(stats.game_stats, :finish_positions, updated_positions)

    %{stats | game_stats: updated_game_stats}
  end

  @spec calculate_player_score(player_stats(), game_stats()) :: integer()
  def calculate_player_score(player_stats, _game_stats) do
    base_score =
      if player_stats.games_won > 0 do
        # Winner bonus
        1000
      else
        0
      end

    # Efficiency bonuses
    card_efficiency = max(0, 100 - player_stats.total_cards_drawn)
    special_bonus = player_stats.special_cards_played * 10

    # Speed bonus for quick wins
    speed_bonus =
      case player_stats.quickest_win_turns do
        nil -> 0
        turns when turns < 20 -> 200
        turns when turns < 30 -> 100
        turns when turns < 50 -> 50
        _ -> 0
      end

    base_score + card_efficiency + special_bonus + speed_bonus
  end

  @spec get_leaderboard(t()) :: [{String.t(), integer()}]
  def get_leaderboard(%__MODULE__{} = stats) do
    stats.player_stats
    |> Enum.map(fn {player_id, player_stats} ->
      score = calculate_player_score(player_stats, stats.game_stats)
      {player_id, player_stats, score}
    end)
    |> Enum.sort_by(fn {_, _, score} -> score end, :desc)
  end

  @spec format_stats(t()) :: map()
  def format_stats(%__MODULE__{} = stats) do
    %{
      game: %{
        total_turns: stats.game_stats.total_turns,
        total_cards_played: stats.game_stats.total_cards_played,
        duration_minutes: format_duration(stats.game_stats.game_duration_seconds),
        winner: stats.game_stats.winner_id
      },
      players:
        Enum.map(get_leaderboard(stats), fn {id, player_stats, score} ->
          %{
            id: id,
            score: score,
            cards_played: player_stats.total_cards_played,
            cards_drawn: player_stats.total_cards_drawn,
            won: player_stats.games_won > 0
          }
        end)
    }
  end

  defp has_special_effect?(card) do
    Card.special_effect(card) != nil
  end

  defp format_duration(nil), do: "In progress"
  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end

  @doc """
  Calculate stats from a completed game instance.
  This is used for persisting stats when a game ends.
  """
  @spec calculate_stats(Game.t()) :: map()
  def calculate_stats(game) do
    player_names =
      game.players
      |> Enum.map(fn player -> {player.id, player.name} end)
      |> Map.new()

    # Extract basic game stats
    game_stats = build_game_stats(game)

    # Extract player-specific stats
    player_stats =
      game.players
      |> Enum.map(fn player ->
        player_stats_from_game =
          if game.stats && Map.has_key?(game.stats.player_stats, player.id) do
            game.stats.player_stats[player.id]
          else
            %{
              total_cards_played: 0,
              total_cards_drawn: 0,
              special_cards_played: 0,
              games_won: 0
            }
          end

        finish_position = Enum.find_index(game.winners, &(&1 == player.id))
        won = player.id in game.winners

        # Build full player_stats record for score calculation
        full_player_stats = %{
          games_played: 1,
          games_won: if(won, do: 1, else: 0),
          total_cards_played: Map.get(player_stats_from_game, :total_cards_played, 0),
          total_cards_drawn: Map.get(player_stats_from_game, :total_cards_drawn, 0),
          special_cards_played: Map.get(player_stats_from_game, :special_cards_played, 0),
          average_finish_position: 0.0,
          quickest_win_turns: nil,
          longest_game_turns: 0
        }

        score = calculate_player_score(full_player_stats, game_stats)

        {player.id,
         %{
           player_name: player.name,
           finish_position: finish_position,
           cards_played: full_player_stats.total_cards_played,
           cards_drawn: full_player_stats.total_cards_drawn,
           special_cards_played: full_player_stats.special_cards_played,
           won: won,
           score: score
         }}
      end)
      |> Map.new()

    %{
      winner_id: game_stats.winner_id,
      total_turns: game_stats.total_turns,
      total_cards_played: game_stats.total_cards_played,
      total_cards_drawn: game_stats.total_cards_drawn,
      special_effects_triggered: game_stats.special_effects_triggered,
      direction_changes: game_stats.direction_changes,
      suit_nominations: game_stats.suit_nominations,
      finish_positions: game_stats.finish_positions,
      player_names: player_names,
      player_stats: player_stats
    }
  end

  defp build_game_stats(game) do
    default_stats = %{
      winner_id: List.first(game.winners),
      total_turns: 0,
      total_cards_played: 0,
      total_cards_drawn: 0,
      special_effects_triggered: 0,
      direction_changes: 0,
      suit_nominations: 0,
      finish_positions: game.winners,
      game_duration_seconds: nil
    }

    if game.stats && game.stats.game_stats do
      Map.merge(default_stats, %{
        total_turns: game.stats.game_stats.total_turns,
        total_cards_played: game.stats.game_stats.total_cards_played,
        total_cards_drawn: game.stats.game_stats.total_cards_drawn,
        special_effects_triggered: game.stats.game_stats.special_effects_triggered,
        direction_changes: game.stats.game_stats.direction_changes,
        suit_nominations: game.stats.game_stats.suit_nominations
      })
    else
      default_stats
    end
  end
end
