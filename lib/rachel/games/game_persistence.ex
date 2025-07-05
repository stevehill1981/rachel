defmodule Rachel.Games.GamePersistence do
  @moduledoc """
  Handles persistence of game state to the database for recovery across deployments.

  This module provides:
  - Automatic saving of game state during gameplay
  - Recovery of active games on server restart
  - Cleanup of old/completed games
  - Efficient serialization/deserialization of game data
  """

  use GenServer
  require Logger

  alias Rachel.Repo
  alias Rachel.Games.{Game, GameManager, GameServer, GameState}
  import Ecto.Query

  # Save every 30 seconds
  @save_interval_ms 30_000
  # Cleanup every 5 minutes
  @cleanup_interval_ms 300_000
  # Remove games older than 24 hours
  @max_game_age_hours 24

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Saves the current state of a game to the database.
  """
  def save_game_state(game_id, game_state) do
    GenServer.cast(__MODULE__, {:save_game, game_id, game_state})
  end

  @doc """
  Loads a saved game state from the database.
  """
  def load_game_state(game_id) do
    case Repo.get_by(GameState, game_id: game_id) do
      nil ->
        {:error, :not_found}

      game_state ->
        try do
          state = Jason.decode!(game_state.game_data)
          {:ok, deserialize_game_state(state)}
        rescue
          _ -> {:error, :invalid_state}
        end
    end
  end

  @doc """
  Recovers all active games from the database and restarts their GameServers.
  Called on application startup.
  """
  def recover_active_games do
    GenServer.call(__MODULE__, :recover_games)
  end

  @doc """
  Removes a game from persistence (when game ends or is deleted).
  """
  def delete_game_state(game_id) do
    GenServer.cast(__MODULE__, {:delete_game, game_id})
  end

  ## Server Implementation

  @impl true
  def init(_opts) do
    # Schedule periodic tasks
    :timer.send_interval(@save_interval_ms, :save_active_games)
    :timer.send_interval(@cleanup_interval_ms, :cleanup_old_games)

    {:ok, %{}}
  end

  @impl true
  def handle_call(:recover_games, _from, state) do
    count = recover_games_from_db()
    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_cast({:save_game, game_id, game_state}, state) do
    save_game_to_db(game_id, game_state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_game, game_id}, state) do
    delete_game_from_db(game_id)
    {:noreply, state}
  end

  @impl true
  def handle_info(:save_active_games, state) do
    save_all_active_games()
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_old_games, state) do
    cleanup_old_games()
    {:noreply, state}
  end

  ## Private Functions

  defp recover_games_from_db do
    Repo.all(GameState)
    |> Enum.map(&recover_single_game/1)
    |> Enum.count(&(&1 == :ok))
  end

  defp recover_single_game(game_state_record) do
    try do
      game_state =
        game_state_record.game_data
        |> Jason.decode!()
        |> deserialize_game_state()

      case DynamicSupervisor.start_child(
             Rachel.GameSupervisor,
             {GameServer, game_id: game_state_record.game_id}
           ) do
        {:ok, _pid} ->
          GameServer.set_state(game_state_record.game_id, game_state)
          Logger.info("Recovered game: #{game_state_record.game_id}")
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to recover game #{game_state_record.game_id}: #{inspect(reason)}"
          )

          :error
      end
    rescue
      error ->
        Logger.error("Error recovering game #{game_state_record.game_id}: #{inspect(error)}")
        :error
    end
  end

  defp save_all_active_games do
    case GameManager.list_active_games() do
      games when is_list(games) ->
        Enum.each(games, fn game ->
          case GameServer.get_state(game.id) do
            # Game not found, skip
            nil -> :ok
            game_state -> save_game_to_db(game.id, game_state)
          end
        end)

      _ ->
        :ok
    end
  end

  defp save_game_to_db(game_id, game_state) do
    try do
      serialized_state =
        game_state
        |> serialize_game_state()
        |> Jason.encode!()

      attrs = %{
        game_id: game_id,
        game_data: serialized_state,
        status: Atom.to_string(game_state.status || :waiting),
        player_count: length(game_state.players || []),
        host_id: get_host_id(game_state)
      }

      case Repo.get_by(GameState, game_id: game_id) do
        nil ->
          %GameState{}
          |> GameState.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> GameState.changeset(attrs)
          |> Repo.update()
      end
    rescue
      error ->
        Logger.error("Failed to save game #{game_id}: #{inspect(error)}")
        :error
    end
  end

  defp delete_game_from_db(game_id) do
    case Repo.get_by(GameState, game_id: game_id) do
      nil -> :ok
      game_state -> Repo.delete(game_state)
    end
  end

  defp cleanup_old_games do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@max_game_age_hours, :hour)

    query =
      from g in GameState,
        where: g.updated_at < ^cutoff_time or g.status in ["finished", "cancelled"]

    Repo.delete_all(query)
  end

  defp get_host_id(game_state) do
    cond do
      Map.has_key?(game_state, :host_id) ->
        game_state.host_id

      Map.has_key?(game_state, :players) and length(game_state.players) > 0 ->
        List.first(game_state.players).id

      true ->
        nil
    end
  end

  # Serialize/deserialize functions to handle complex data types
  defp serialize_game_state(game_state) do
    # Convert atoms to strings, handle special types
    case game_state do
      %{__struct__: _} ->
        game_state
        |> Map.from_struct()
        |> serialize_nested_data()

      _ when is_map(game_state) ->
        serialize_nested_data(game_state)

      _ ->
        # Not a valid game state structure
        raise ArgumentError,
              "Invalid game state: expected struct or map, got #{inspect(game_state)}"
    end
  end

  defp serialize_nested_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {serialize_key(k), serialize_nested_data(v)} end)
  end

  defp serialize_nested_data(data) when is_list(data) do
    Enum.map(data, &serialize_nested_data/1)
  end

  defp serialize_nested_data(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_nested_data(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp serialize_nested_data(data), do: data

  defp serialize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp serialize_key(key), do: key

  defp deserialize_game_state(data) when is_map(data) do
    data
    |> Map.new(fn {k, v} -> {deserialize_key(k), deserialize_nested_data(v)} end)
    |> convert_to_game_struct()
  end

  defp deserialize_nested_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {deserialize_key(k), deserialize_nested_data(v)} end)
  end

  defp deserialize_nested_data(data) when is_list(data) do
    Enum.map(data, &deserialize_nested_data/1)
  end

  # Handle datetime strings
  defp deserialize_nested_data(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> deserialize_string_to_atom(str)
    end
  end

  defp deserialize_nested_data(data), do: data

  defp deserialize_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp deserialize_key(key), do: key

  # Convert known string values back to atoms
  defp deserialize_string_to_atom(str) do
    string_to_atom_map = %{
      "waiting" => :waiting,
      "playing" => :playing,
      "finished" => :finished,
      "hearts" => :hearts,
      "diamonds" => :diamonds,
      "clubs" => :clubs,
      "spades" => :spades,
      "clockwise" => :clockwise,
      "counter_clockwise" => :counter_clockwise
    }

    Map.get(string_to_atom_map, str, str)
  end

  defp convert_to_game_struct(data) do
    # Convert back to Game struct if it has the right shape
    if Map.has_key?(data, :id) and Map.has_key?(data, :players) do
      struct(Game, data)
    else
      data
    end
  end
end
