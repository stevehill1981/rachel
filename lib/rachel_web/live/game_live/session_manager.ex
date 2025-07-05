defmodule RachelWeb.GameLive.SessionManager do
  @moduledoc """
  Handles player session management and game joining logic for GameLive.

  This module is responsible for:
  - Player identity management (ID and name extraction from session)
  - Game joining and reconnection logic
  - Spectator joining logic
  - Error handling and formatting for join operations
  """

  alias Rachel.Games.GameServer

  @type game_id :: String.t()
  @type player_id :: String.t()
  @type player_name :: String.t()
  @type join_error ::
          :game_not_found
          | :game_started
          | :game_full
          | :already_joined
          | :game_not_started
          | :already_spectating
          | :already_playing
          | any()

  @doc """
  Extracts or generates a player ID from the session.
  """
  @spec get_player_id(map()) :: player_id()
  def get_player_id(session) do
    session[:player_id] ||
      "player_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  @doc """
  Extracts a player name from the session, defaulting to "Anonymous".
  """
  @spec get_player_name(map()) :: player_name()
  def get_player_name(session) do
    session[:player_name] || "Anonymous"
  end

  @doc """
  Handles the complete game joining process.
  Returns {:ok, game}, {:ok, game, :spectator}, or {:error, reason}.
  """
  @spec handle_game_join(game_id(), player_id(), player_name()) ::
          {:ok, map()} | {:ok, map(), :spectator} | {:error, join_error()}
  def handle_game_join(game_id, player_id, player_name) do
    case GameServer.get_state(game_id) do
      game when is_map(game) ->
        join_or_reconnect_player(game_id, game, player_id, player_name)

      _ ->
        {:error, :game_not_found}
    end
  catch
    :exit, _ ->
      {:error, :game_not_found}
  end

  @doc """
  Determines whether to join as a new player or reconnect an existing player.
  """
  @spec join_or_reconnect_player(game_id(), map(), player_id(), player_name()) ::
          {:ok, map()} | {:ok, map(), :spectator} | {:error, join_error()}
  def join_or_reconnect_player(game_id, game, player_id, player_name) do
    in_game = player_in_game?(game, player_id)

    if in_game do
      reconnect_existing_player(game_id, player_id)
    else
      join_new_player(game_id, player_id, player_name)
    end
  end

  @doc """
  Reconnects an existing player to the game.
  """
  @spec reconnect_existing_player(game_id(), player_id()) :: {:ok, map()}
  def reconnect_existing_player(game_id, player_id) do
    # GameServer.reconnect_player only returns :ok
    :ok = GameServer.reconnect_player(game_id, player_id)
    updated_game = GameServer.get_state(game_id)
    {:ok, updated_game}
  end

  @doc """
  Joins a new player to the game or attempts to join as spectator if game started.
  """
  def join_new_player(game_id, player_id, player_name) do
    case GameServer.join_game(game_id, player_id, player_name) do
      {:ok, updated_game} ->
        {:ok, updated_game}

      {:error, :game_started} ->
        try_join_as_spectator(game_id, player_id, player_name)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Attempts to join the game as a spectator.
  """
  def try_join_as_spectator(game_id, player_id, player_name) do
    case GameServer.join_as_spectator(game_id, player_id, player_name) do
      {:ok, updated_game} ->
        {:ok, updated_game, :spectator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a player is already in the game.
  """
  def player_in_game?(game, player_id) do
    Enum.any?(game.players, &(&1.id == player_id))
  end

  @doc """
  Formats join error messages for display to users.
  """
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:game_not_found), do: "Game not found"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:game_started), do: "Game has already started"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:game_full), do: "Game is full"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:already_joined), do: "You're already in this game"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:game_not_started), do: "Cannot spectate a game that hasn't started yet"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:already_spectating), do: "You're already spectating this game"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(:already_playing), do: "You're already playing in this game"
  @spec format_join_error(join_error()) :: String.t()
  def format_join_error(error), do: "Error joining game: #{inspect(error)}"
end
