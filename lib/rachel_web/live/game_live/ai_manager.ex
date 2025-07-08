defmodule RachelWeb.GameLive.AIManager do
  @moduledoc """
  Handles AI logic and processing for GameLive single-player games.

  This module is responsible for:
  - Scheduling AI moves
  - Processing AI decisions
  - Executing AI actions (play, draw, nominate)
  - Managing AI thinking indicators

  Note: Multiplayer AI moves are handled by GameServer.
  """

  alias Rachel.Games.{AIPlayer, Game}
  alias RachelWeb.GameLive.StateManager

  @doc """
  Schedules an AI move if the current player is AI in a single-player game.
  """
  def schedule_ai_move(%Game{} = game) do
    # Only schedule AI moves for single-player games
    # Multiplayer AI moves are handled by GameServer
    current = Game.current_player(game)

    if current && current.is_ai && game.status == :playing do
      Process.send_after(self(), :ai_move, 1500)
    end
  end

  @doc """
  Handles AI move processing for single-player games.
  Returns {:ok, updates} or {:noreply}.
  """
  def handle_single_player_ai_move(game) do
    current = Game.current_player(game)

    if should_process_ai_move?(game, current) do
      process_ai_move(game, current)
    else
      {:noreply}
    end
  end

  @doc """
  Processes an AI move by determining the action and executing it.
  Returns {:ok, updates} or {:noreply}.
  """
  def process_ai_move(game, current) do
    case AIPlayer.make_move(game, current.id) do
      {:play, cards} ->
        execute_ai_play(game, current.id, cards)

      {:nominate, suit} ->
        execute_ai_nominate(game, current.id, suit)

      {:draw, _} ->
        execute_ai_draw(game, current.id)

      _ ->
        {:noreply}
    end
  end

  @doc """
  Executes an AI card play action.
  Returns {:ok, updates} or falls back to draw.
  """
  def execute_ai_play(game, ai_id, cards) do
    case Game.play_card(game, ai_id, cards) do
      {:ok, new_game} ->
        updates = [
          {:assign, :game, StateManager.normalize_game_data(new_game)},
          {:assign, :show_ai_thinking, false},
          {:schedule_ai_move, new_game}
        ]

        # Add auto-draw check updates for human player
        human_player_id = find_human_player_id(new_game)
        auto_draw_updates = StateManager.check_auto_draw_updates(new_game, human_player_id)
        {:ok, updates ++ auto_draw_updates}

      _ ->
        # If play fails, try drawing
        execute_ai_draw(game, ai_id)
    end
  end

  @doc """
  Executes an AI suit nomination action.
  Returns {:ok, updates} or {:noreply}.
  """
  def execute_ai_nominate(game, ai_id, suit) do
    case Game.nominate_suit(game, ai_id, suit) do
      {:ok, new_game} ->
        updates = [
          {:assign, :game, StateManager.normalize_game_data(new_game)},
          {:assign, :show_ai_thinking, false},
          {:schedule_ai_move, new_game}
        ]

        # Add auto-draw check updates for human player
        human_player_id = find_human_player_id(new_game)
        auto_draw_updates = StateManager.check_auto_draw_updates(new_game, human_player_id)
        {:ok, updates ++ auto_draw_updates}

      _ ->
        {:noreply}
    end
  end

  @doc """
  Executes an AI draw card action.
  Returns {:ok, updates} or {:noreply}.
  """
  def execute_ai_draw(game, ai_id) do
    case AIPlayer.make_move(game, ai_id) do
      {:draw, _} ->
        case Game.draw_card(game, ai_id) do
          {:ok, new_game} ->
            updates = [
              {:assign, :game, StateManager.normalize_game_data(new_game)},
              {:assign, :show_ai_thinking, false},
              {:schedule_ai_move, new_game}
            ]

            {:ok, updates}

          _ ->
            {:noreply}
        end

      _ ->
        {:noreply}
    end
  end

  # Private helper functions

  defp should_process_ai_move?(game, current) do
    current && current.is_ai && game.status == :playing
  end

  defp find_human_player_id(game) do
    human_player = Enum.find(game.players, fn player -> !player.is_ai end)
    if human_player, do: human_player.id, else: "human"
  end
end
