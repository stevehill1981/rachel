defmodule RachelWeb.GameLive.PubSubHandlers do
  @moduledoc """
  Handles PubSub message processing for GameLive multiplayer games.

  This module is responsible for:
  - Processing real-time game updates
  - Handling player action notifications
  - Managing connection status changes
  - Displaying appropriate flash messages for multiplayer events
  """

  alias RachelWeb.GameLive.StateManager

  @doc """
  Handles game_updated PubSub messages.
  Returns socket updates.
  """
  def handle_game_updated(game, player_id) do
    updates = [
      {:assign, :game, StateManager.normalize_game_data(game)},
      {:assign, :selected_cards, []}
    ]

    winner_updates = StateManager.check_and_show_winner_banner_updates(game, player_id)
    updates ++ winner_updates
  end

  @doc """
  Handles cards_played PubSub messages.
  Returns socket updates.
  """
  def handle_cards_played(
        %{player_id: player_id, cards: cards, game: game} = msg,
        current_player_id
      ) do
    updates = [
      {:assign, :game, StateManager.normalize_game_data(game)},
      {:assign, :selected_cards, []}
    ]

    winner_updates = StateManager.check_and_show_winner_banner_updates(game, current_player_id)
    updates = updates ++ winner_updates

    if player_id != current_player_id do
      # Use player_name from message if available, otherwise look it up
      player_name = Map.get(msg, :player_name) || get_player_name_by_id(game, player_id)
      card_count = length(cards)

      message =
        "#{player_name} played #{card_count} card#{if card_count == 1, do: "", else: "s"}"

      updates ++ [{:put_flash, :info, message}]
    else
      updates
    end
  end

  @doc """
  Handles card_drawn PubSub messages.
  Returns socket updates.
  """
  def handle_card_drawn(%{player_id: player_id, game: game}, current_player_id) do
    updates = [{:assign, :game, game}]

    if player_id != current_player_id do
      player_name = get_player_name_by_id(game, player_id)
      updates ++ [{:put_flash, :info, "#{player_name} drew a card"}]
    else
      updates
    end
  end

  @doc """
  Handles suit_nominated PubSub messages.
  Returns socket updates.
  """
  def handle_suit_nominated(%{player_id: player_id, suit: suit, game: game}, current_player_id) do
    updates = [{:assign, :game, game}]

    if player_id != current_player_id do
      player_name = get_player_name_by_id(game, player_id)
      updates ++ [{:put_flash, :info, "#{player_name} nominated suit: #{suit}"}]
    else
      updates
    end
  end

  @doc """
  Handles player_won PubSub messages.
  Returns socket updates.
  """
  def handle_player_won(%{player_id: winner_player_id} = _msg, current_player_id) do
    # Simple winner handling without game updates
    if winner_player_id == current_player_id do
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
  Handles game_started PubSub messages.
  Returns socket updates.
  """
  def handle_game_started(game) do
    [{:assign, :game, game}]
  end

  @doc """
  Handles player_reconnected PubSub messages.
  Returns socket updates.
  """
  def handle_player_reconnected(
        %{player_id: player_id, player_name: player_name},
        current_player_id
      ) do
    if player_id != current_player_id do
      [{:put_flash, :info, "#{player_name} reconnected"}]
    else
      []
    end
  end

  @doc """
  Handles player_disconnected PubSub messages.
  Returns socket updates.
  """
  def handle_player_disconnected(
        %{player_id: player_id, player_name: player_name},
        current_player_id
      ) do
    if player_id != current_player_id do
      [{:put_flash, :info, "#{player_name} disconnected"}]
    else
      []
    end
  end

  @doc """
  Handles auto_draw_pending_cards messages for forced card drawing.
  Returns socket updates or :noreply.
  """
  def handle_auto_draw_pending_cards(game, player_id) do
    current_player = current_player(game)

    # Double-check conditions are still met - only auto-draw multiple cards
    if current_player &&
         current_player.id == player_id &&
         game.pending_pickups > 1 &&
         !Rachel.Games.Game.has_valid_play?(game, current_player) &&
         game.status == :playing do
      pickup_count = game.pending_pickups
      pickup_type = game.pending_pickup_type

      # Return action to be executed by main module
      message =
        if pickup_type == :black_jacks do
          "Drew #{pickup_count} cards from Black Jacks!"
        else
          "Drew #{pickup_count} cards from 2s!"
        end

      {:draw_card_with_message, message}
    else
      :noreply
    end
  end

  @doc """
  Handles auto_hide_winner_banner messages.
  Returns socket updates.
  """
  def handle_auto_hide_winner_banner do
    [{:assign, :show_winner_banner, false}]
  end

  # Private helper functions

  defp get_player_name_by_id(game, player_id) do
    case Enum.find(game.players, &(&1.id == player_id)) do
      %{name: name} -> name
      _ -> "Unknown"
    end
  end

  defp current_player(%Rachel.Games.Game{} = game) do
    Rachel.Games.Game.current_player(game)
  end

  defp current_player(_), do: nil

  # draw_card_action will be called from main module
end
