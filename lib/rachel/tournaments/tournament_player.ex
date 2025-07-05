defmodule Rachel.Tournaments.TournamentPlayer do
  @moduledoc """
  Represents a player registration in a tournament.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Rachel.Repo
  alias Rachel.Tournaments.Tournament

  @type registration_status :: :registered | :checked_in | :playing | :eliminated | :withdrawn

  schema "tournament_players" do
    field :player_id, :string
    field :player_name, :string
    field :seed, :integer

    field :status, Ecto.Enum,
      values: [:registered, :checked_in, :playing, :eliminated, :withdrawn],
      default: :registered

    field :eliminated_round, :integer
    field :final_position, :integer
    field :points, :integer, default: 0
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :byes, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :tournament, Tournament

    timestamps()
  end

  @doc false
  def changeset(tournament_player, attrs) do
    tournament_player
    |> cast(attrs, [
      :tournament_id,
      :player_id,
      :player_name,
      :seed,
      :status,
      :eliminated_round,
      :final_position,
      :points,
      :wins,
      :losses,
      :byes,
      :metadata
    ])
    |> validate_required([:tournament_id, :player_id, :player_name])
    |> validate_length(:player_name, min: 1, max: 50)
    |> validate_number(:seed, greater_than: 0)
    |> validate_number(:points, greater_than_or_equal_to: 0)
    |> validate_number(:wins, greater_than_or_equal_to: 0)
    |> validate_number(:losses, greater_than_or_equal_to: 0)
    |> validate_number(:byes, greater_than_or_equal_to: 0)
    |> unique_constraint([:tournament_id, :player_id])
    |> foreign_key_constraint(:tournament_id)
  end

  @doc """
  Creates a player registration for a tournament.
  """
  def create_registration(tournament_id, player_id, player_name, opts \\ []) do
    seed = Keyword.get(opts, :seed)
    metadata = Keyword.get(opts, :metadata, %{})

    attrs = %{
      tournament_id: tournament_id,
      player_id: player_id,
      player_name: player_name,
      seed: seed,
      metadata: metadata
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a player's tournament status.
  """
  def update_status(tournament_id, player_id, new_status, opts \\ []) do
    case get_player(tournament_id, player_id) do
      nil ->
        {:error, :not_found}

      player ->
        attrs = %{status: new_status}

        # Add optional fields
        attrs =
          if eliminated_round = Keyword.get(opts, :eliminated_round) do
            Map.put(attrs, :eliminated_round, eliminated_round)
          else
            attrs
          end

        attrs =
          if final_position = Keyword.get(opts, :final_position) do
            Map.put(attrs, :final_position, final_position)
          else
            attrs
          end

        player
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Records a match result for a player.
  """
  def record_match_result(tournament_id, player_id, result) do
    case get_player(tournament_id, player_id) do
      nil ->
        {:error, :not_found}

      player ->
        attrs =
          case result do
            :win -> %{wins: player.wins + 1, points: player.points + 3}
            :loss -> %{losses: player.losses + 1}
            :bye -> %{byes: player.byes + 1, points: player.points + 3}
            :draw -> %{points: player.points + 1}
          end

        player
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Gets a player in a tournament.
  """
  def get_player(tournament_id, player_id) do
    Repo.get_by(__MODULE__, tournament_id: tournament_id, player_id: player_id)
  end

  @doc """
  Lists all players in a tournament.
  """
  def list_tournament_players(tournament_id, opts \\ []) do
    status_filter = Keyword.get(opts, :status)
    order_by = Keyword.get(opts, :order_by, :seed)

    query =
      from(tp in __MODULE__,
        where: tp.tournament_id == ^tournament_id
      )

    query =
      if status_filter do
        from(tp in query, where: tp.status == ^status_filter)
      else
        query
      end

    query =
      case order_by do
        :seed -> from(tp in query, order_by: [asc: :seed, asc: :inserted_at])
        :points -> from(tp in query, order_by: [desc: :points, desc: :wins, asc: :losses])
        :name -> from(tp in query, order_by: :player_name)
        :status -> from(tp in query, order_by: :status)
      end

    Repo.all(query)
  end

  @doc """
  Gets tournament standings/leaderboard.
  """
  def get_standings(tournament_id) do
    query =
      from(tp in __MODULE__,
        where: tp.tournament_id == ^tournament_id,
        order_by: [
          desc: :points,
          desc: :wins,
          asc: :losses,
          asc: :final_position
        ]
      )

    players = Repo.all(query)

    # Calculate positions
    players
    |> Enum.with_index(1)
    |> Enum.map(fn {player, position} ->
      %{player | final_position: position}
    end)
  end

  @doc """
  Assigns seeds to players (for seeded tournaments).
  """
  def assign_seeds(tournament_id, seeding_method \\ :random) do
    players = list_tournament_players(tournament_id, status: :registered)

    seeded_players =
      case seeding_method do
        :random -> Enum.shuffle(players)
        :registration_order -> Enum.sort_by(players, & &1.inserted_at)
        :alphabetical -> Enum.sort_by(players, & &1.player_name)
      end

    seeded_players
    |> Enum.with_index(1)
    |> Enum.each(fn {player, seed} ->
      player
      |> changeset(%{seed: seed})
      |> Repo.update()
    end)

    {:ok, seeded_players}
  end

  @doc """
  Withdraws a player from the tournament.
  """
  def withdraw_player(tournament_id, player_id, reason \\ nil) do
    case get_player(tournament_id, player_id) do
      nil ->
        {:error, :not_found}

      player ->
        metadata =
          if reason do
            Map.put(player.metadata, :withdrawal_reason, reason)
          else
            player.metadata
          end

        player
        |> changeset(%{status: :withdrawn, metadata: metadata})
        |> Repo.update()
    end
  end

  @doc """
  Checks if a tournament is full.
  """
  def tournament_full?(tournament_id) do
    with %Tournament{max_players: max_players} <- Repo.get(Tournament, tournament_id) do
      current_count =
        Repo.aggregate(
          from(tp in __MODULE__, where: tp.tournament_id == ^tournament_id),
          :count
        )

      current_count >= max_players
    else
      nil -> false
    end
  end

  @doc """
  Gets active players (not withdrawn/eliminated) for bracket generation.
  """
  def get_active_players(tournament_id) do
    query =
      from(tp in __MODULE__,
        where:
          tp.tournament_id == ^tournament_id and
            tp.status in [:registered, :checked_in, :playing],
        order_by: :seed
      )

    Repo.all(query)
  end

  @doc """
  Eliminates players who lost in a specific round.
  """
  def eliminate_players(tournament_id, round, player_ids) do
    query =
      from(tp in __MODULE__,
        where:
          tp.tournament_id == ^tournament_id and
            tp.player_id in ^player_ids
      )

    Repo.update_all(query,
      set: [
        status: :eliminated,
        eliminated_round: round
      ]
    )
  end
end
