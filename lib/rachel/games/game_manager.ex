defmodule Rachel.Games.GameManager do
  @moduledoc """
  Manages multiple game sessions, handles game creation, joining, and cleanup.
  """

  alias Rachel.Games.GameServer

  @type game_id :: String.t()
  @type player_id :: String.t()
  @type game_info :: %{
          id: game_id(),
          players: non_neg_integer(),
          status: atom(),
          host_id: player_id() | nil
        }

  @doc """
  Creates a new game session with a unique game ID.
  Returns the game ID for players to join.
  """
  @spec create_game(String.t()) :: {:ok, game_id()} | {:error, any()}
  def create_game(_creator_name \\ "Host") do
    game_id = generate_game_id()

    case DynamicSupervisor.start_child(Rachel.GameSupervisor, {GameServer, game_id: game_id}) do
      {:ok, _pid} ->
        # Optionally auto-join the creator
        # GameServer.join_game(game_id, creator_id, creator_name)
        {:ok, game_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a game and immediately joins the creator.
  """
  @spec create_and_join_game(player_id(), String.t()) :: {:ok, game_id()} | {:error, any()}
  def create_and_join_game(creator_id, creator_name) do
    case create_game() do
      {:ok, game_id} ->
        case GameServer.join_game(game_id, creator_id, creator_name) do
          {:ok, _game} ->
            {:ok, game_id}

          {:error, reason} ->
            # Clean up the game if join fails
            stop_game(game_id)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Joins an existing game by game ID.
  """
  @spec join_game(game_id(), player_id(), String.t()) :: {:ok, map()} | {:error, atom()}
  def join_game(game_id, player_id, player_name) do
    if game_exists?(game_id) do
      try do
        GameServer.join_game(game_id, player_id, player_name)
      catch
        :exit, {:noproc, _} ->
          {:error, :game_not_found}

        :exit, _ ->
          {:error, :game_not_found}
      end
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Lists all active games with their basic info.
  """
  @spec list_active_games() :: [game_info()]
  def list_active_games do
    Registry.select(Rachel.GameRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.map(fn game_id ->
      try do
        state = GameServer.get_state(game_id)

        case state do
          nil ->
            nil

          state when is_map(state) ->
            %{
              id: game_id,
              status: state.status,
              player_count: length(state.players),
              players:
                Enum.map(state.players, fn p -> %{id: p.id, name: p.name, is_ai: p.is_ai} end),
              # We could track this in GameServer if needed
              created_at: DateTime.utc_now()
            }
        end
      catch
        :exit, {:noproc, _} ->
          # Game process is dead, skip it
          nil

        :exit, {:timeout, _} ->
          # Game server not responding, skip it
          nil

        :exit, _ ->
          # Other server errors, skip it
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets detailed info about a specific game.
  """
  @spec get_game_info(game_id()) ::
          {:ok, map()} | {:error, :game_not_found | :server_error | :server_timeout}
  def get_game_info(game_id) do
    if game_exists?(game_id) do
      try do
        state = GameServer.get_state(game_id)

        case state do
          nil ->
            {:error, :game_not_found}

          state when is_map(state) ->
            {:ok,
             %{
               id: game_id,
               status: state.status,
               player_count: length(state.players),
               # Could be configurable
               max_players: 8,
               players:
                 Enum.map(state.players, fn p ->
                   %{id: p.id, name: p.name, is_ai: p.is_ai, connected: p.connected}
                 end),
               current_player_id: state.current_player_id,
               can_join: state.status == :waiting and length(state.players) < 8
             }}
        end
      catch
        :exit, {:noproc, _} ->
          {:error, :game_not_found}

        :exit, {:timeout, _} ->
          {:error, :server_timeout}

        :exit, _ ->
          {:error, :server_error}
      end
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Stops a game session (for cleanup or admin purposes).
  """
  @spec stop_game(game_id()) :: :ok | {:error, :not_found}
  def stop_game(game_id) do
    case Registry.lookup(Rachel.GameRegistry, game_id) do
      [{pid, _}] ->
        case DynamicSupervisor.terminate_child(Rachel.GameSupervisor, pid) do
          :ok -> :ok
          {:error, :not_found} -> {:error, :game_not_found}
        end

      [] ->
        {:error, :game_not_found}
    end
  end

  @doc """
  Checks if a game exists and is running.
  """
  @spec game_exists?(game_id()) :: boolean()
  def game_exists?(game_id) do
    case Registry.lookup(Rachel.GameRegistry, game_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Generates a short, user-friendly game code.
  """
  @spec generate_game_code() :: String.t()
  def generate_game_code do
    # Generate a 6-character alphanumeric code
    :crypto.strong_rand_bytes(3)
    |> Base.encode16()
    |> String.upcase()
  end

  @doc """
  Cleans up finished games that have been inactive.
  Could be called periodically or triggered by game completion.
  """
  @spec cleanup_finished_games(non_neg_integer()) :: :ok
  def cleanup_finished_games(_max_age_hours \\ 24) do
    list_active_games()
    |> Enum.filter(fn game ->
      # In a real implementation, we'd track game finish time
      # For now, just clean up games with no players
      game.player_count == 0 or game.status == :finished
    end)
    |> Enum.each(fn %{id: id} = _game ->
      try do
        stop_game(id)
      rescue
        # Any other error, continue cleanup
        _ -> :ok
      catch
        # Process already dead, that's fine
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  # Private helper functions

  defp generate_game_id do
    "game-#{System.unique_integer([:positive])}"
  end
end
