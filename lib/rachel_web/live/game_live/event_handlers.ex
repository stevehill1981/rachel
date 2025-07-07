defmodule RachelWeb.GameLive.EventHandlers do
  @moduledoc """
  Handles user interaction events for GameLive.

  This module is responsible for:
  - Card selection and validation logic
  - Play cards event processing
  - Draw card event handling
  - Suit nomination event processing
  - Auto-play logic for single cards
  """

  alias Rachel.Games.{Card, Game}
  alias RachelWeb.GameLive.{Actions, StateManager}

  @doc """
  Handles card selection events with validation.
  Returns socket updates as a list of operations.
  """
  def handle_card_selection(selected_cards, current_player, index) do
    if index in selected_cards do
      # Deselect the card
      {:ok, {:assign, :selected_cards, List.delete(selected_cards, index)}}
    else
      handle_card_click(current_player, index, selected_cards)
    end
  end

  @doc """
  Handles play cards events with validation.
  Returns {:ok, updates} or {:error, reason}.
  """
  def handle_play_cards(game, player_id, selected_cards) do
    case validate_play_cards_request(game, player_id, selected_cards) do
      :ok ->
        execute_play_cards(game, player_id, selected_cards)

      :invalid ->
        {:error, :invalid_request}
    end
  end

  @doc """
  Handles draw card events.
  Returns {:ok, updates} or {:error, reason}.
  """
  def handle_draw_card(socket) do
    case Actions.draw_card_action(socket) do
      {:ok, new_game} ->
        updates = [
          {:assign, :game, StateManager.normalize_game_data(new_game)},
          {:assign, :selected_cards, []},
          {:clear_flash},
          {:put_flash, :info, "Card drawn!"}
        ]

        # Add AI move scheduling for single-player games
        updates =
          if socket.assigns.game_id == nil do
            updates ++ [{:schedule_ai_move, new_game}]
          else
            updates
          end

        {:ok, updates}

      {:error, reason} ->
        {:error, Actions.format_error(reason)}
    end
  end

  @doc """
  Handles suit nomination events.
  Returns {:ok, updates} or {:error, reason}.
  """
  def handle_nominate_suit(socket, suit_atom, suit_string) do
    case Actions.nominate_suit_action(socket, suit_atom) do
      {:ok, new_game} ->
        updates = [
          {:assign, :game, StateManager.normalize_game_data(new_game)},
          {:clear_flash},
          {:put_flash, :info, "Suit nominated: #{suit_string}"}
        ]

        # Add AI move scheduling for single-player games
        updates =
          if socket.assigns.game_id == nil do
            updates ++ [{:schedule_ai_move, new_game}]
          else
            updates
          end

        {:ok, updates}

      {:error, reason} ->
        {:error, Actions.format_error(reason)}
    end
  end

  @doc """
  Validates if a player can select a specific card.
  """
  def can_select_card?(%Game{} = game, %Card{} = card, selected_indices, hand) do
    current = Game.current_player(game)
    valid_plays = Game.get_valid_plays(game, current)
    
    # Can always select if nothing selected yet
    if Enum.empty?(selected_indices) do
      # Check if it's a valid play
      Enum.any?(valid_plays, fn {valid_card, _} ->
        valid_card.suit == card.suit && valid_card.rank == card.rank
      end)
    else
      # If cards are already selected, check if:
      # 1. New card has same rank as selected cards
      # 2. At least one card of this rank is a valid play
      first_selected_index = hd(selected_indices)
      first_card = Enum.at(hand, first_selected_index)

      if first_card && card.rank == first_card.rank do
        # Check if any card of this rank is a valid play
        Enum.any?(valid_plays, fn {valid_card, _} ->
          valid_card.rank == card.rank
        end)
      else
        false
      end
    end
  end

  # Private helper functions

  defp handle_card_click(current_player, index, selected) do
    clicked_card = Enum.at(current_player.hand, index)

    if clicked_card do
      # Return the selection update - validation will be done at the caller level
      {:ok, {:assign, :selected_cards, selected ++ [index]}}
    else
      # Can't select this card
      {:error, :invalid_card}
    end
  end

  # This function is no longer needed - logic moved to handle_card_click

  # Auto-play logic moved to main GameLive module

  defp validate_play_cards_request(game, player_id, selected_cards) do
    current_player = current_player(game)

    if current_player &&
         current_player.id == player_id &&
         length(selected_cards) > 0 do
      :ok
    else
      :invalid
    end
  end

  defp execute_play_cards(_game, _player_id, selected_cards) do
    # This will be called from the main GameLive module
    # Return the action to be executed
    {:ok, {:play_cards_action, selected_cards}}
  end

  # Auto-play logic moved to main GameLive module

  defp current_player(%Game{} = game) do
    Game.current_player(game)
  end

  defp current_player(_), do: nil

  # AI move scheduling moved to AIManager module
end
