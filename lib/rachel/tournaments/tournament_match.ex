defmodule Rachel.Tournaments.TournamentMatch do
  @moduledoc """
  Represents a match in a tournament between two players.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Rachel.Repo
  alias Rachel.Tournaments.{Tournament, TournamentPlayer}

  @type match_status :: :pending | :in_progress | :completed | :cancelled
  @type bracket_type :: :winners | :losers | :finals

  schema "tournament_matches" do
    field :round, :integer
    field :match_number, :integer
    field :bracket_type, Ecto.Enum, values: [:winners, :losers, :finals], default: :winners

    field :status, Ecto.Enum,
      values: [:pending, :in_progress, :completed, :cancelled],
      default: :pending

    field :player1_id, :string
    field :player2_id, :string
    field :winner_id, :string
    field :loser_id, :string

    # Reference to actual game session
    field :game_id, :string
    field :scheduled_time, :utc_datetime
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    # Store match scores/results
    field :score, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :tournament, Tournament

    timestamps()
  end

  @doc false
  def changeset(tournament_match, attrs) do
    tournament_match
    |> cast(attrs, [
      :tournament_id,
      :round,
      :match_number,
      :bracket_type,
      :status,
      :player1_id,
      :player2_id,
      :winner_id,
      :loser_id,
      :game_id,
      :scheduled_time,
      :started_at,
      :completed_at,
      :score,
      :metadata
    ])
    |> validate_required([:tournament_id, :round, :match_number])
    |> validate_number(:round, greater_than: 0)
    |> validate_number(:match_number, greater_than: 0)
    |> validate_players_different()
    |> validate_winner_is_player()
    |> foreign_key_constraint(:tournament_id)
  end

  @doc """
  Creates a new tournament match.
  """
  def create_match(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Starts a match (sets it to in_progress).
  """
  def start_match(match_id, game_id \\ nil) do
    case Repo.get(__MODULE__, match_id) do
      nil ->
        {:error, :not_found}

      %{status: :pending} = match ->
        attrs = %{
          status: :in_progress,
          started_at: DateTime.utc_now()
        }

        attrs = if game_id, do: Map.put(attrs, :game_id, game_id), else: attrs

        match
        |> changeset(attrs)
        |> Repo.update()

      _ ->
        {:error, :match_not_pending}
    end
  end

  @doc """
  Completes a match with the winner.
  """
  def complete_match(match_id, winner_id, score \\ %{}) do
    case Repo.get(__MODULE__, match_id) do
      nil ->
        {:error, :not_found}

      %{status: status} = match when status in [:pending, :in_progress] ->
        if winner_id in [match.player1_id, match.player2_id] do
          loser_id =
            if winner_id == match.player1_id, do: match.player2_id, else: match.player1_id

          attrs = %{
            status: :completed,
            winner_id: winner_id,
            loser_id: loser_id,
            completed_at: DateTime.utc_now(),
            score: score
          }

          result =
            match
            |> changeset(attrs)
            |> Repo.update()

          # Update player records
          case result do
            {:ok, updated_match} ->
              update_player_records(updated_match)
              {:ok, updated_match}

            error ->
              error
          end
        else
          {:error, :invalid_winner}
        end

      _ ->
        {:error, :match_not_active}
    end
  end

  @doc """
  Cancels a match.
  """
  def cancel_match(match_id, reason \\ nil) do
    case Repo.get(__MODULE__, match_id) do
      nil ->
        {:error, :not_found}

      %{status: status} = match when status in [:pending, :in_progress] ->
        metadata =
          if reason do
            Map.put(match.metadata, :cancellation_reason, reason)
          else
            match.metadata
          end

        match
        |> changeset(%{status: :cancelled, metadata: metadata})
        |> Repo.update()

      _ ->
        {:error, :cannot_cancel}
    end
  end

  @doc """
  Gets matches for a specific tournament and round.
  """
  def get_round_matches(tournament_id, round, bracket_type \\ :winners) do
    query =
      from(m in __MODULE__,
        where:
          m.tournament_id == ^tournament_id and
            m.round == ^round and
            m.bracket_type == ^bracket_type,
        order_by: :match_number
      )

    Repo.all(query)
  end

  @doc """
  Gets all matches for a tournament.
  """
  def get_tournament_matches(tournament_id, opts \\ []) do
    status_filter = Keyword.get(opts, :status)
    bracket_filter = Keyword.get(opts, :bracket_type)

    query =
      from(m in __MODULE__,
        where: m.tournament_id == ^tournament_id,
        order_by: [asc: :round, asc: :match_number]
      )

    query =
      if status_filter do
        from(m in query, where: m.status == ^status_filter)
      else
        query
      end

    query =
      if bracket_filter do
        from(m in query, where: m.bracket_type == ^bracket_filter)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets matches involving a specific player.
  """
  def get_player_matches(tournament_id, player_id) do
    query =
      from(m in __MODULE__,
        where:
          m.tournament_id == ^tournament_id and
            (m.player1_id == ^player_id or m.player2_id == ^player_id),
        order_by: [asc: :round, asc: :match_number]
      )

    Repo.all(query)
  end

  @doc """
  Checks if all matches in a round are completed.
  """
  def round_completed?(tournament_id, round, bracket_type \\ :winners) do
    incomplete_count =
      Repo.aggregate(
        from(m in __MODULE__,
          where:
            m.tournament_id == ^tournament_id and
              m.round == ^round and
              m.bracket_type == ^bracket_type and
              m.status != :completed
        ),
        :count
      )

    incomplete_count == 0
  end

  @doc """
  Gets winners from a completed round.
  """
  def get_round_winners(tournament_id, round, bracket_type \\ :winners) do
    query =
      from(m in __MODULE__,
        where:
          m.tournament_id == ^tournament_id and
            m.round == ^round and
            m.bracket_type == ^bracket_type and
            m.status == :completed and
            not is_nil(m.winner_id),
        select: m.winner_id,
        order_by: :match_number
      )

    Repo.all(query)
  end

  @doc """
  Gets losers from a completed round (for double elimination).
  """
  def get_round_losers(tournament_id, round, bracket_type \\ :winners) do
    query =
      from(m in __MODULE__,
        where:
          m.tournament_id == ^tournament_id and
            m.round == ^round and
            m.bracket_type == ^bracket_type and
            m.status == :completed and
            not is_nil(m.loser_id),
        select: m.loser_id,
        order_by: :match_number
      )

    Repo.all(query)
  end

  @doc """
  Reschedules a match.
  """
  def reschedule_match(match_id, new_time) do
    case Repo.get(__MODULE__, match_id) do
      nil ->
        {:error, :not_found}

      %{status: :pending} = match ->
        match
        |> changeset(%{scheduled_time: new_time})
        |> Repo.update()

      _ ->
        {:error, :cannot_reschedule}
    end
  end

  @doc """
  Awards a bye (automatic win) to a player.
  """
  def award_bye(tournament_id, round, match_number, player_id) do
    attrs = %{
      tournament_id: tournament_id,
      round: round,
      match_number: match_number,
      player1_id: player_id,
      player2_id: nil,
      winner_id: player_id,
      status: :completed,
      completed_at: DateTime.utc_now(),
      metadata: %{is_bye: true}
    }

    result = create_match(attrs)

    case result do
      {:ok, match} ->
        # Record bye for player
        TournamentPlayer.record_match_result(tournament_id, player_id, :bye)
        {:ok, match}

      error ->
        error
    end
  end

  @doc """
  Gets upcoming matches (scheduled for soon).
  """
  def get_upcoming_matches(tournament_id, within_minutes \\ 60) do
    cutoff_time = DateTime.add(DateTime.utc_now(), within_minutes * 60, :second)

    query =
      from(m in __MODULE__,
        where:
          m.tournament_id == ^tournament_id and
            m.status == :pending and
            not is_nil(m.scheduled_time) and
            m.scheduled_time <= ^cutoff_time,
        order_by: :scheduled_time
      )

    Repo.all(query)
  end

  # Private helper functions

  defp validate_players_different(changeset) do
    player1 = get_field(changeset, :player1_id)
    player2 = get_field(changeset, :player2_id)

    if player1 && player2 && player1 == player2 do
      add_error(changeset, :player2_id, "cannot be the same as player1")
    else
      changeset
    end
  end

  defp validate_winner_is_player(changeset) do
    winner = get_field(changeset, :winner_id)
    player1 = get_field(changeset, :player1_id)
    player2 = get_field(changeset, :player2_id)

    if winner && winner not in [player1, player2] do
      add_error(changeset, :winner_id, "must be one of the match players")
    else
      changeset
    end
  end

  defp update_player_records(match) do
    if match.winner_id do
      TournamentPlayer.record_match_result(match.tournament_id, match.winner_id, :win)
    end

    if match.loser_id do
      TournamentPlayer.record_match_result(match.tournament_id, match.loser_id, :loss)
    end
  end
end
