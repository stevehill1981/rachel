defmodule Rachel.Tournaments.Tournament do
  @moduledoc """
  Tournament management system for competitive Rachel gameplay.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Rachel.Repo
  alias Rachel.Tournaments.{TournamentMatch, TournamentPlayer}

  @type tournament_status :: :registration | :starting | :in_progress | :completed | :cancelled
  @type tournament_format :: :single_elimination | :double_elimination | :round_robin | :swiss

  schema "tournaments" do
    field :name, :string
    field :description, :string

    field :format, Ecto.Enum,
      values: [:single_elimination, :double_elimination, :round_robin, :swiss]

    field :status, Ecto.Enum,
      values: [:registration, :starting, :in_progress, :completed, :cancelled]

    field :max_players, :integer
    field :entry_fee, :integer, default: 0
    field :prize_pool, :integer, default: 0
    field :registration_deadline, :utc_datetime
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :current_round, :integer, default: 0
    field :total_rounds, :integer
    field :settings, :map, default: %{}
    field :creator_id, :string
    field :winner_id, :string
    field :is_public, :boolean, default: true
    field :metadata, :map, default: %{}

    has_many :tournament_players, TournamentPlayer
    has_many :matches, TournamentMatch

    timestamps()
  end

  @doc false
  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, [
      :name,
      :description,
      :format,
      :status,
      :max_players,
      :entry_fee,
      :prize_pool,
      :registration_deadline,
      :start_time,
      :end_time,
      :current_round,
      :total_rounds,
      :settings,
      :creator_id,
      :winner_id,
      :is_public,
      :metadata
    ])
    |> validate_required([:name, :format, :max_players, :creator_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:max_players, greater_than: 1, less_than_or_equal_to: 64)
    |> validate_number(:entry_fee, greater_than_or_equal_to: 0)
    |> validate_number(:prize_pool, greater_than_or_equal_to: 0)
    |> validate_change(:registration_deadline, &validate_future_datetime/2)
    |> validate_change(:start_time, &validate_future_datetime/2)
    |> calculate_total_rounds()
  end

  @doc """
  Creates a new tournament.
  """
  def create_tournament(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a tournament by ID with all associations.
  """
  def get_tournament_full(id) do
    from(t in __MODULE__,
      where: t.id == ^id,
      preload: [:tournament_players, :matches]
    )
    |> Repo.one()
  end

  @doc """
  Lists tournaments with optional filters.
  """
  def list_tournaments(opts \\ []) do
    status_filter = Keyword.get(opts, :status)
    format_filter = Keyword.get(opts, :format)
    limit_val = Keyword.get(opts, :limit, 20)
    public_only = Keyword.get(opts, :public_only, true)

    query =
      from(t in __MODULE__,
        order_by: [desc: :inserted_at],
        limit: ^limit_val,
        preload: [:tournament_players]
      )

    query =
      if public_only do
        from(t in query, where: t.is_public == true)
      else
        query
      end

    query =
      if status_filter do
        from(t in query, where: t.status == ^status_filter)
      else
        query
      end

    query =
      if format_filter do
        from(t in query, where: t.format == ^format_filter)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Registers a player for a tournament.
  """
  def register_player(tournament_id, player_id, player_name) do
    with {:ok, tournament} <- get_registrable_tournament(tournament_id),
         {:ok, _} <- validate_registration(tournament, player_id) do
      TournamentPlayer.create_registration(tournament_id, player_id, player_name)
    end
  end

  @doc """
  Starts a tournament if conditions are met.
  """
  def start_tournament(tournament_id, starter_id) do
    with {:ok, tournament} <- get_startable_tournament(tournament_id, starter_id),
         {:ok, _} <- validate_start_conditions(tournament) do
      # Update tournament status
      tournament
      |> changeset(%{
        status: :starting,
        start_time: DateTime.utc_now(),
        current_round: 1
      })
      |> Repo.update()
      |> case do
        {:ok, updated_tournament} ->
          # Generate first round matches
          generate_bracket(updated_tournament)

          updated_tournament
          |> changeset(%{status: :in_progress})
          |> Repo.update()

        error ->
          error
      end
    end
  end

  @doc """
  Advances tournament to next round or completes it.
  """
  def advance_tournament(tournament_id) do
    with {:ok, tournament} <- get_tournament_for_advancement(tournament_id),
         {:ok, _} <- validate_round_completion(tournament) do
      if tournament.current_round >= tournament.total_rounds do
        complete_tournament(tournament)
      else
        advance_to_next_round(tournament)
      end
    end
  end

  @doc """
  Gets tournament leaderboard/standings.
  """
  def get_leaderboard(tournament_id) do
    case get_tournament_full(tournament_id) do
      nil -> {:error, :not_found}
      tournament -> {:ok, calculate_standings(tournament)}
    end
  end

  # Private helper functions

  defp validate_future_datetime(field, datetime) do
    case DateTime.compare(datetime, DateTime.utc_now()) do
      :gt -> []
      _ -> [{field, "must be in the future"}]
    end
  end

  defp calculate_total_rounds(changeset) do
    case {get_field(changeset, :format), get_field(changeset, :max_players)} do
      {:single_elimination, max_players} when is_integer(max_players) ->
        rounds = :math.ceil(:math.log2(max_players)) |> trunc()
        put_change(changeset, :total_rounds, rounds)

      {:double_elimination, max_players} when is_integer(max_players) ->
        rounds = (:math.ceil(:math.log2(max_players)) * 2 - 1) |> trunc()
        put_change(changeset, :total_rounds, rounds)

      {:round_robin, max_players} when is_integer(max_players) ->
        rounds = max_players - 1
        put_change(changeset, :total_rounds, rounds)

      {:swiss, _} ->
        # Swiss rounds are typically calculated based on player count
        # Default 5 rounds
        put_change(changeset, :total_rounds, 5)

      _ ->
        changeset
    end
  end

  defp get_registrable_tournament(tournament_id) do
    case Repo.get(__MODULE__, tournament_id) do
      nil -> {:error, :not_found}
      %{status: :registration} = tournament -> {:ok, tournament}
      _ -> {:error, :registration_closed}
    end
  end

  defp validate_registration(tournament, player_id) do
    # Check if player is already registered
    existing = Repo.get_by(TournamentPlayer, tournament_id: tournament.id, player_id: player_id)

    if existing do
      {:error, :already_registered}
    else
      # Check if tournament is full
      player_count =
        Repo.aggregate(
          from(tp in TournamentPlayer, where: tp.tournament_id == ^tournament.id),
          :count
        )

      if player_count >= tournament.max_players do
        {:error, :tournament_full}
      else
        {:ok, :can_register}
      end
    end
  end

  defp get_startable_tournament(tournament_id, starter_id) do
    case Repo.get(__MODULE__, tournament_id) do
      nil -> {:error, :not_found}
      %{creator_id: ^starter_id, status: :registration} = tournament -> {:ok, tournament}
      %{creator_id: creator_id} when creator_id != starter_id -> {:error, :not_authorized}
      _ -> {:error, :cannot_start}
    end
  end

  defp validate_start_conditions(tournament) do
    player_count =
      Repo.aggregate(
        from(tp in TournamentPlayer, where: tp.tournament_id == ^tournament.id),
        :count
      )

    min_players =
      case tournament.format do
        :single_elimination -> 2
        :double_elimination -> 2
        :round_robin -> 3
        :swiss -> 4
      end

    if player_count >= min_players do
      {:ok, :can_start}
    else
      {:error, :not_enough_players}
    end
  end

  defp generate_bracket(tournament) do
    players =
      Repo.all(
        from(tp in TournamentPlayer,
          where: tp.tournament_id == ^tournament.id,
          order_by: :inserted_at
        )
      )

    case tournament.format do
      :single_elimination -> generate_single_elimination_bracket(tournament, players)
      :double_elimination -> generate_double_elimination_bracket(tournament, players)
      :round_robin -> generate_round_robin_bracket(tournament, players)
      :swiss -> generate_swiss_bracket(tournament, players)
    end
  end

  defp generate_single_elimination_bracket(tournament, players) do
    # Pair players for first round
    pairs = Enum.chunk_every(players, 2, 2, [nil])

    Enum.with_index(pairs, fn pair, index ->
      case pair do
        [player1, player2] when not is_nil(player2) ->
          TournamentMatch.create_match(%{
            tournament_id: tournament.id,
            round: 1,
            match_number: index + 1,
            player1_id: player1.player_id,
            player2_id: player2.player_id,
            status: :pending
          })

        [player1] ->
          # Bye - player advances automatically
          TournamentMatch.create_match(%{
            tournament_id: tournament.id,
            round: 1,
            match_number: index + 1,
            player1_id: player1.player_id,
            player2_id: nil,
            status: :completed,
            winner_id: player1.player_id
          })
      end
    end)
  end

  defp generate_double_elimination_bracket(_tournament, _players) do
    # TODO: Implement double elimination bracket generation
    {:ok, :bracket_generated}
  end

  defp generate_round_robin_bracket(_tournament, _players) do
    # TODO: Implement round robin bracket generation
    {:ok, :bracket_generated}
  end

  defp generate_swiss_bracket(_tournament, _players) do
    # TODO: Implement Swiss system bracket generation
    {:ok, :bracket_generated}
  end

  defp get_tournament_for_advancement(tournament_id) do
    case get_tournament_full(tournament_id) do
      nil -> {:error, :not_found}
      %{status: :in_progress} = tournament -> {:ok, tournament}
      _ -> {:error, :tournament_not_in_progress}
    end
  end

  defp validate_round_completion(tournament) do
    # Check if all matches in current round are completed
    incomplete_matches =
      Repo.aggregate(
        from(m in TournamentMatch,
          where:
            m.tournament_id == ^tournament.id and
              m.round == ^tournament.current_round and
              m.status != :completed
        ),
        :count
      )

    if incomplete_matches == 0 do
      {:ok, :round_complete}
    else
      {:error, :round_not_complete}
    end
  end

  defp advance_to_next_round(tournament) do
    # Generate next round matches based on current round winners
    next_round = tournament.current_round + 1

    # Get winners from current round
    winners =
      Repo.all(
        from(m in TournamentMatch,
          where:
            m.tournament_id == ^tournament.id and
              m.round == ^tournament.current_round and
              not is_nil(m.winner_id),
          select: m.winner_id
        )
      )

    # Generate next round matches
    generate_next_round_matches(tournament, winners, next_round)

    # Update tournament
    tournament
    |> changeset(%{current_round: next_round})
    |> Repo.update()
  end

  defp generate_next_round_matches(tournament, winners, round) do
    case tournament.format do
      :single_elimination ->
        winners
        |> Enum.chunk_every(2)
        |> Enum.with_index()
        |> Enum.each(fn {pair, index} ->
          case pair do
            [player1, player2] ->
              TournamentMatch.create_match(%{
                tournament_id: tournament.id,
                round: round,
                match_number: index + 1,
                player1_id: player1,
                player2_id: player2,
                status: :pending
              })

            [player1] ->
              # Bye - player advances
              TournamentMatch.create_match(%{
                tournament_id: tournament.id,
                round: round,
                match_number: index + 1,
                player1_id: player1,
                player2_id: nil,
                status: :completed,
                winner_id: player1
              })
          end
        end)

      _ ->
        # Other formats would have different logic
        :ok
    end
  end

  defp complete_tournament(tournament) do
    # Find tournament winner
    winner_id =
      case tournament.format do
        :single_elimination -> find_single_elimination_winner(tournament)
        # Other formats would have different logic
        _ -> nil
      end

    tournament
    |> changeset(%{
      status: :completed,
      end_time: DateTime.utc_now(),
      winner_id: winner_id
    })
    |> Repo.update()
  end

  defp find_single_elimination_winner(tournament) do
    final_match =
      Repo.one(
        from(m in TournamentMatch,
          where: m.tournament_id == ^tournament.id and m.round == ^tournament.total_rounds,
          limit: 1
        )
      )

    case final_match do
      %{winner_id: winner_id} when not is_nil(winner_id) -> winner_id
      _ -> nil
    end
  end

  defp calculate_standings(tournament) do
    # Calculate player standings based on tournament format and results
    case tournament.format do
      :single_elimination -> calculate_elimination_standings(tournament)
      :round_robin -> calculate_round_robin_standings(tournament)
      :swiss -> calculate_swiss_standings(tournament)
      _ -> []
    end
  end

  defp calculate_elimination_standings(tournament) do
    # For elimination tournaments, standings are based on how far players advanced
    players = tournament.tournament_players

    Enum.map(players, fn player ->
      last_round = get_player_last_round(tournament.id, player.player_id)
      wins = count_player_wins(tournament.id, player.player_id)
      losses = count_player_losses(tournament.id, player.player_id)

      %{
        player_id: player.player_id,
        player_name: player.player_name,
        # Will be calculated based on last_round
        position: nil,
        last_round: last_round,
        wins: wins,
        losses: losses,
        points: calculate_elimination_points(last_round, tournament.total_rounds)
      }
    end)
    |> Enum.sort_by(&{-&1.last_round, -&1.wins})
    |> Enum.with_index(1)
    |> Enum.map(fn {standing, position} -> %{standing | position: position} end)
  end

  defp calculate_round_robin_standings(_tournament) do
    # TODO: Implement round robin standings
    []
  end

  defp calculate_swiss_standings(_tournament) do
    # TODO: Implement Swiss standings
    []
  end

  defp get_player_last_round(tournament_id, player_id) do
    Repo.one(
      from(m in TournamentMatch,
        where:
          m.tournament_id == ^tournament_id and
            (m.player1_id == ^player_id or m.player2_id == ^player_id),
        select: max(m.round)
      )
    ) || 0
  end

  defp count_player_wins(tournament_id, player_id) do
    Repo.aggregate(
      from(m in TournamentMatch,
        where: m.tournament_id == ^tournament_id and m.winner_id == ^player_id
      ),
      :count
    )
  end

  defp count_player_losses(tournament_id, player_id) do
    Repo.aggregate(
      from(m in TournamentMatch,
        where:
          m.tournament_id == ^tournament_id and
            (m.player1_id == ^player_id or m.player2_id == ^player_id) and
            m.status == :completed and
            m.winner_id != ^player_id
      ),
      :count
    )
  end

  defp calculate_elimination_points(last_round, total_rounds) do
    # Points based on how far the player advanced
    case last_round do
      # Champion
      ^total_rounds -> 100
      # Runner-up  
      r when r == total_rounds - 1 -> 75
      # Semi-finalist
      r when r == total_rounds - 2 -> 50
      # Quarter-finalist
      r when r == total_rounds - 3 -> 25
      # Earlier rounds
      _ -> last_round * 5
    end
  end
end
