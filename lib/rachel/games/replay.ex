defmodule Rachel.Games.Replay do
  @moduledoc """
  Game replay system for recording and playing back game sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Rachel.Repo

  @type replay_state :: :recording | :paused | :playing | :finished
  @type playback_speed :: float()

  schema "game_replays" do
    field :game_id, :string
    field :title, :string
    field :description, :string
    field :duration_seconds, :integer
    field :total_moves, :integer
    field :player_names, {:array, :string}
    field :winner_name, :string
    # JSON-encoded game events
    field :game_data, :string
    field :metadata, :map
    field :is_public, :boolean, default: false
    field :view_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(replay, attrs) do
    replay
    |> cast(attrs, [
      :game_id,
      :title,
      :description,
      :duration_seconds,
      :total_moves,
      :player_names,
      :winner_name,
      :game_data,
      :metadata,
      :is_public
    ])
    |> validate_required([:game_id, :title, :game_data])
    |> validate_length(:title, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> unique_constraint(:game_id)
  end

  @doc """
  Creates a new replay from game events.
  """
  def create_replay(game_id, events, metadata \\ %{}) do
    game_data = Jason.encode!(events)

    attrs = %{
      game_id: game_id,
      title: generate_title(metadata),
      description: generate_description(metadata),
      duration_seconds: calculate_duration(events),
      total_moves: length(events),
      player_names: extract_player_names(events),
      winner_name: extract_winner(events),
      game_data: game_data,
      metadata: metadata
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Loads a replay by ID.
  """
  def get_replay(id) do
    case Repo.get(__MODULE__, id) do
      nil ->
        {:error, :not_found}

      replay ->
        # Increment view count
        query = from(r in __MODULE__, where: r.id == ^id)
        Repo.update_all(query, inc: [view_count: 1])

        # Decode game data
        case Jason.decode(replay.game_data) do
          {:ok, events} -> {:ok, %{replay | game_data: events}}
          {:error, _} -> {:error, :invalid_data}
        end
    end
  end

  @doc """
  Lists public replays with optional filters.
  """
  def list_public_replays(opts \\ []) do
    limit_val = Keyword.get(opts, :limit, 20)
    offset_val = Keyword.get(opts, :offset, 0)
    order_by_val = Keyword.get(opts, :order_by, :inserted_at)

    query =
      from(r in __MODULE__,
        where: r.is_public == true,
        order_by: [desc: ^order_by_val],
        limit: ^limit_val,
        offset: ^offset_val,
        select: [
          :id,
          :title,
          :description,
          :duration_seconds,
          :total_moves,
          :player_names,
          :winner_name,
          :view_count,
          :inserted_at
        ]
      )

    Repo.all(query)
  end

  @doc """
  Searches replays by title or player names.
  """
  def search_replays(search_query, opts \\ []) do
    limit_val = Keyword.get(opts, :limit, 20)

    search_term = "%#{String.downcase(search_query)}%"
    player_search = String.downcase(search_query)

    query =
      from(r in __MODULE__,
        where: r.is_public == true,
        where:
          fragment("LOWER(?) LIKE ?", r.title, ^search_term) or
            fragment("? = ANY(?)", ^player_search, r.player_names),
        order_by: [desc: :view_count, desc: :inserted_at],
        limit: ^limit_val,
        select: [
          :id,
          :title,
          :description,
          :duration_seconds,
          :total_moves,
          :player_names,
          :winner_name,
          :view_count,
          :inserted_at
        ]
      )

    Repo.all(query)
  end

  # Private helper functions

  defp generate_title(%{winner_name: winner, player_count: count}) when is_binary(winner) do
    "#{winner} vs #{count - 1} others"
  end

  defp generate_title(%{player_names: names}) when is_list(names) do
    case length(names) do
      2 -> "#{Enum.at(names, 0)} vs #{Enum.at(names, 1)}"
      count -> "#{count}-Player Game"
    end
  end

  defp generate_title(_), do: "Recorded Game"

  defp generate_description(%{special_cards_played: count, total_turns: turns}) do
    "Game lasted #{turns} turns with #{count} special cards played"
  end

  defp generate_description(%{total_turns: turns}) do
    "Game lasted #{turns} turns"
  end

  defp generate_description(_), do: "No description available"

  defp calculate_duration(events) do
    case {List.first(events), List.last(events)} do
      {%{timestamp: start}, %{timestamp: finish}} ->
        DateTime.diff(finish, start, :second)

      _ ->
        # Estimate 2 seconds per move
        length(events) * 2
    end
  end

  defp extract_player_names(events) do
    events
    |> Enum.flat_map(fn event ->
      case event do
        %{player_name: name} when is_binary(name) -> [name]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp extract_winner(events) do
    win_event =
      Enum.find(events, fn event ->
        Map.get(event, :type) == :game_won
      end)

    case win_event do
      %{player_name: name} -> name
      _ -> nil
    end
  end
end
