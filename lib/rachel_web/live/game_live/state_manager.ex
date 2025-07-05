defmodule RachelWeb.GameLive.StateManager do
  @moduledoc """
  Handles game state management and data normalization for GameLive.

  This module is responsible for:
  - Normalizing game data to ensure all required fields are present
  - Managing winner banner display logic
  - Handling auto-draw logic for forced card draws
  - State validation and cleanup
  """

  alias Rachel.Games.{Deck, Game}

  @doc """
  Normalizes game data to ensure all required fields are present.
  This prevents defensive programming in components.
  """
  def normalize_game_data(nil), do: nil

  def normalize_game_data(%Game{} = game) do
    # Game struct should already have all fields, just ensure they're not nil
    %{
      game
      | deck: game.deck || %Deck{cards: [], discarded: []},
        discard_pile: game.discard_pile || [],
        players: game.players || [],
        current_card: game.current_card,
        pending_pickups: game.pending_pickups || 0,
        pending_skips: game.pending_skips || 0,
        winners: game.winners || []
    }
  end

  def normalize_game_data(game) when is_map(game) do
    # Convert plain maps to proper Game structs with defaults
    %Game{
      id: Map.get(game, :id),
      status: Map.get(game, :status, :waiting),
      players: Map.get(game, :players, []),
      current_player_index: Map.get(game, :current_player_index, 0),
      current_card: Map.get(game, :current_card),
      deck: Map.get(game, :deck, %Deck{cards: [], discarded: []}),
      discard_pile: Map.get(game, :discard_pile, []),
      direction: Map.get(game, :direction, :clockwise),
      pending_pickups: Map.get(game, :pending_pickups, 0),
      pending_pickup_type: Map.get(game, :pending_pickup_type),
      pending_skips: Map.get(game, :pending_skips, 0),
      nominated_suit: Map.get(game, :nominated_suit),
      winners: Map.get(game, :winners, []),
      stats: Map.get(game, :stats, %Rachel.Games.Stats{})
    }
  end

  def normalize_game_data(_), do: nil

  @doc """
  Returns socket updates to check and show winner banner if appropriate.
  """
  def check_and_show_winner_banner_updates(nil, _player_id), do: []

  def check_and_show_winner_banner_updates(game, player_id) do
    winners = Map.get(game, :winners, [])

    # Check if the current player just won
    if player_id in winners do
      [
        {:assign, :show_winner_banner, true},
        {:assign, :winner_acknowledged, true},
        {:send_after_self, :auto_hide_winner_banner, 5000}
      ]
    else
      []
    end
  end

  @doc """
  Returns socket updates to check if auto-draw should be triggered.
  """
  def check_auto_draw_updates(game, player_id) do
    current_player = current_player(game)

    # Only auto-draw if player has MULTIPLE cards to pick up (2s or black jacks)
    # Single card draws should be manual
    if current_player &&
         current_player.id == player_id &&
         game.pending_pickups > 1 &&
         !Game.has_valid_play?(game, current_player) &&
         game.status == :playing do
      # Schedule auto-draw after a delay
      [{:send_after_self, :auto_draw_pending_cards, 2000}]
    else
      []
    end
  end

  @doc """
  Gets the current player's name for display purposes.
  """
  def current_player_name(%Game{} = game) do
    case Game.current_player(game) do
      nil -> "None"
      player -> player.name
    end
  end

  @doc """
  Gets the current player from the game.
  """
  def current_player(%Game{} = game) do
    Game.current_player(game)
  end

  def current_player(_), do: nil

  @doc """
  Validates that it's the player's turn.
  """
  def validate_player_turn(socket) do
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      {:ok, current_player}
    else
      :not_player_turn
    end
  end

  @doc """
  Gets a player's name by their ID from the game.
  """
  def get_player_name_by_id(game, player_id) do
    case Enum.find(game.players, &(&1.id == player_id)) do
      %{name: name} -> name
      _ -> "Unknown"
    end
  end
end
