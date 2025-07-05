defmodule Rachel.Accounts.Stats do
  @moduledoc """
  The Stats context for persisting game statistics to the database.
  """

  import Ecto.Query, warn: false
  alias Rachel.Repo

  alias Rachel.Accounts.{GameRecord, PlayerStats, PlayerProfile}
  alias Rachel.Games.Stats

  @doc """
  Records a completed game and all player statistics.
  """
  def record_game(game, game_id, started_at, ended_at) do
    game_stats = Stats.calculate_stats(game)

    Repo.transaction(fn ->
      # Create game record
      {:ok, game_record} =
        create_game_record(%{
          game_id: game_id,
          status: "completed",
          winner_id: game_stats.winner_id,
          total_turns: game_stats.total_turns,
          total_cards_played: game_stats.total_cards_played,
          total_cards_drawn: game_stats.total_cards_drawn,
          special_effects_triggered: game_stats.special_effects_triggered,
          direction_changes: game_stats.direction_changes,
          suit_nominations: game_stats.suit_nominations,
          game_duration_seconds: calculate_duration(started_at, ended_at),
          finish_positions: game_stats.finish_positions,
          player_names: game_stats.player_names,
          started_at: started_at,
          ended_at: ended_at
        })

      # Create player stats for each player
      Enum.each(game_stats.player_stats, fn {player_id, stats} ->
        user_id = get_user_id_for_player(player_id)

        create_player_stats(%{
          user_id: user_id,
          player_id: player_id,
          player_name: stats.player_name,
          game_record_id: game_record.id,
          finish_position: stats.finish_position,
          cards_played: stats.cards_played,
          cards_drawn: stats.cards_drawn,
          special_cards_played: stats.special_cards_played,
          won: stats.won,
          score: stats.score
        })

        # Update aggregate player profile
        update_player_profile(player_id, stats, user_id)
      end)

      game_record
    end)
  end

  @doc """
  Gets all game records.
  """
  def list_game_records do
    Repo.all(GameRecord)
  end

  @doc """
  Gets a single game record.
  """
  def get_game_record!(id), do: Repo.get!(GameRecord, id)

  @doc """
  Creates a game record.
  """
  def create_game_record(attrs \\ %{}) do
    %GameRecord{}
    |> GameRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets player stats for a specific game.
  """
  def get_player_stats_for_game(game_record_id) do
    PlayerStats
    |> where([p], p.game_record_id == ^game_record_id)
    |> Repo.all()
  end

  @doc """
  Gets all player stats for a specific player.
  """
  def get_player_stats(player_id) do
    PlayerStats
    |> where([p], p.player_id == ^player_id)
    |> preload(:game_record)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates player stats.
  """
  def create_player_stats(attrs \\ %{}) do
    %PlayerStats{}
    |> PlayerStats.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a player profile.
  """
  def get_player_profile(player_id) do
    PlayerProfile
    |> where([p], p.player_id == ^player_id)
    |> Repo.one()
  end

  @doc """
  Gets leaderboard data sorted by total score.
  """
  def get_leaderboard(limit \\ 10) do
    PlayerProfile
    |> order_by([p], desc: p.total_score, desc: p.total_games_won)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Creates or updates a player profile.
  """
  def upsert_player_profile(attrs \\ %{}) do
    case get_player_profile(attrs.player_id) do
      nil ->
        %PlayerProfile{}
        |> PlayerProfile.changeset(attrs)
        |> PlayerProfile.calculate_derived_stats()
        |> Repo.insert()

      existing ->
        existing
        |> PlayerProfile.changeset(attrs)
        |> PlayerProfile.calculate_derived_stats()
        |> Repo.update()
    end
  end

  # Private functions

  defp calculate_duration(started_at, ended_at) do
    case {started_at, ended_at} do
      {%DateTime{} = start, %DateTime{} = finish} ->
        DateTime.diff(finish, start, :second)

      _ ->
        nil
    end
  end

  defp get_user_id_for_player(_player_id) do
    # For now, return nil as we don't have a mapping
    # In the future, this would look up the user_id for authenticated players
    nil
  end

  defp update_player_profile(player_id, game_stats, user_id) do
    existing = get_player_profile(player_id)

    attrs =
      case existing do
        nil ->
          # New profile
          %{
            player_id: player_id,
            display_name: game_stats.player_name,
            user_id: user_id,
            total_games_played: 1,
            total_games_won: if(game_stats.won, do: 1, else: 0),
            total_score: game_stats.score,
            total_cards_played: game_stats.cards_played,
            total_cards_drawn: game_stats.cards_drawn,
            total_special_cards_played: game_stats.special_cards_played,
            current_streak: if(game_stats.won, do: 1, else: 0),
            best_streak: if(game_stats.won, do: 1, else: 0),
            last_played_at: DateTime.utc_now()
          }

        profile ->
          # Update existing profile
          new_total_games = profile.total_games_played + 1
          new_total_wins = profile.total_games_won + if(game_stats.won, do: 1, else: 0)
          new_streak = if(game_stats.won, do: profile.current_streak + 1, else: 0)

          %{
            player_id: player_id,
            total_games_played: new_total_games,
            total_games_won: new_total_wins,
            total_score: profile.total_score + game_stats.score,
            total_cards_played: profile.total_cards_played + game_stats.cards_played,
            total_cards_drawn: profile.total_cards_drawn + game_stats.cards_drawn,
            total_special_cards_played:
              profile.total_special_cards_played + game_stats.special_cards_played,
            current_streak: new_streak,
            best_streak: max(profile.best_streak, new_streak),
            last_played_at: DateTime.utc_now()
          }
      end

    upsert_player_profile(attrs)
  end
end
