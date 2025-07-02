defmodule Rachel.Games.Stats do
  @moduledoc """
  Game statistics tracking and scoring system.
  """

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

  defstruct [
    player_stats: %{},
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
  ]

  def new(player_ids) do
    start_time = DateTime.utc_now()
    
    player_stats = 
      player_ids
      |> Enum.map(fn id -> 
        {id, %{
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

  def record_card_played(%__MODULE__{} = stats, player_id, cards) when is_list(cards) do
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

    %{stats | 
      player_stats: updated_player_stats,
      game_stats: updated_game_stats
    }
  end

  def record_card_drawn(%__MODULE__{} = stats, player_id, card_count) do
    updated_player_stats = 
      Map.update!(stats.player_stats, player_id, fn player_stats ->
        Map.update!(player_stats, :total_cards_drawn, &(&1 + card_count))
      end)

    updated_game_stats = 
      Map.update!(stats.game_stats, :total_cards_drawn, &(&1 + card_count))

    %{stats | 
      player_stats: updated_player_stats,
      game_stats: updated_game_stats
    }
  end

  def record_turn_advance(%__MODULE__{} = stats) do
    updated_game_stats = 
      Map.update!(stats.game_stats, :total_turns, &(&1 + 1))

    %{stats | game_stats: updated_game_stats}
  end

  def record_direction_change(%__MODULE__{} = stats) do
    updated_game_stats = 
      Map.update!(stats.game_stats, :direction_changes, &(&1 + 1))

    %{stats | game_stats: updated_game_stats}
  end

  def record_suit_nomination(%__MODULE__{} = stats) do
    updated_game_stats = 
      Map.update!(stats.game_stats, :suit_nominations, &(&1 + 1))

    %{stats | game_stats: updated_game_stats}
  end

  def record_winner(%__MODULE__{} = stats, winner_id) do
    end_time = DateTime.utc_now()
    duration = DateTime.diff(end_time, stats.start_time)
    
    updated_player_stats = 
      Map.update!(stats.player_stats, winner_id, fn player_stats ->
        turns = stats.game_stats.total_turns
        quickest = player_stats.quickest_win_turns
        
        player_stats
        |> Map.update!(:games_won, &(&1 + 1))
        |> Map.update!(:quickest_win_turns, fn 
          nil -> turns
          current -> min(current, turns)
        end)
        |> Map.update!(:longest_game_turns, &max(&1, turns))
      end)

    updated_game_stats = 
      stats.game_stats
      |> Map.put(:winner_id, winner_id)
      |> Map.put(:game_duration_seconds, duration)

    %{stats | 
      player_stats: updated_player_stats,
      game_stats: updated_game_stats
    }
  end

  def record_finish_position(%__MODULE__{} = stats, player_id) do
    updated_positions = stats.game_stats.finish_positions ++ [player_id]
    updated_game_stats = Map.put(stats.game_stats, :finish_positions, updated_positions)
    
    %{stats | game_stats: updated_game_stats}
  end

  def calculate_player_score(player_stats, game_stats) do
    base_score = cond do
      player_stats.games_won > 0 -> 1000  # Winner bonus
      true -> 0
    end

    # Efficiency bonuses
    card_efficiency = max(0, 100 - player_stats.total_cards_drawn)
    special_bonus = player_stats.special_cards_played * 10
    
    # Speed bonus for quick wins
    speed_bonus = case player_stats.quickest_win_turns do
      nil -> 0
      turns when turns < 20 -> 200
      turns when turns < 30 -> 100
      turns when turns < 50 -> 50
      _ -> 0
    end

    base_score + card_efficiency + special_bonus + speed_bonus
  end

  def get_leaderboard(%__MODULE__{} = stats) do
    stats.player_stats
    |> Enum.map(fn {player_id, player_stats} ->
      score = calculate_player_score(player_stats, stats.game_stats)
      {player_id, player_stats, score}
    end)
    |> Enum.sort_by(fn {_, _, score} -> score end, :desc)
  end

  def format_stats(%__MODULE__{} = stats) do
    %{
      game: %{
        total_turns: stats.game_stats.total_turns,
        total_cards_played: stats.game_stats.total_cards_played,
        duration_minutes: format_duration(stats.game_stats.game_duration_seconds),
        winner: stats.game_stats.winner_id
      },
      players: Enum.map(get_leaderboard(stats), fn {id, player_stats, score} ->
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
    Rachel.Games.Card.special_effect(card) != nil
  end

  defp format_duration(nil), do: "In progress"
  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end
end