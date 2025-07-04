defmodule RachelWeb.GameLive.Actions do
  @moduledoc """
  Handles game action execution for GameLive.

  This module is responsible for:
  - Routing actions to appropriate handlers (multiplayer vs single-player)
  - Playing cards, drawing cards, and nominating suits
  - Error handling for game actions
  """

  alias Rachel.Games.{Game, GameServer}

  @doc """
  Executes a play cards action, routing to multiplayer or single-player handler.
  """
  def play_cards_action(socket, card_indices) do
    if socket.assigns.game_id do
      execute_multiplayer_play_cards(socket, card_indices)
    else
      execute_single_player_play_cards(socket, card_indices)
    end
  end

  @doc """
  Executes a draw card action, routing to multiplayer or single-player handler.
  """
  def draw_card_action(socket) do
    if socket.assigns.game_id do
      execute_multiplayer_draw_card(socket)
    else
      execute_single_player_draw_card(socket)
    end
  end

  @doc """
  Executes a nominate suit action, routing to multiplayer or single-player handler.
  """
  def nominate_suit_action(socket, suit) do
    if socket.assigns.game_id do
      execute_multiplayer_nominate_suit(socket, suit)
    else
      execute_single_player_nominate_suit(socket, suit)
    end
  end

  # Private functions for multiplayer actions

  defp execute_multiplayer_play_cards(socket, card_indices) do
    current_player = current_player(socket.assigns.game)

    if current_player do
      cards = convert_indices_to_cards(current_player.hand, card_indices)

      try do
        case GameServer.play_cards(socket.assigns.game_id, socket.assigns.player_id, cards) do
          {:ok, game} -> {:ok, game}
          {:error, reason} -> {:error, reason}
        end
      catch
        :exit, {:noproc, _} -> {:error, :game_not_found}
        :exit, {:timeout, _} -> {:error, :timeout}
        :exit, reason -> {:error, {:server_error, reason}}
      end
    else
      {:error, :player_not_found}
    end
  end

  defp execute_multiplayer_draw_card(socket) do
    try do
      case GameServer.draw_card(socket.assigns.game_id, socket.assigns.player_id) do
        {:ok, game} -> {:ok, game}
        {:error, reason} -> {:error, reason}
      end
    catch
      :exit, {:noproc, _} -> {:error, :game_not_found}
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, {:server_error, reason}}
    end
  end

  defp execute_multiplayer_nominate_suit(socket, suit) do
    try do
      case GameServer.nominate_suit(socket.assigns.game_id, socket.assigns.player_id, suit) do
        {:ok, game} -> {:ok, game}
        {:error, reason} -> {:error, reason}
      end
    catch
      :exit, {:noproc, _} -> {:error, :game_not_found}
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, {:server_error, reason}}
    end
  end

  # Private functions for single-player actions

  defp execute_single_player_play_cards(socket, card_indices) do
    Game.play_card(socket.assigns.game, socket.assigns.player_id, card_indices)
  end

  defp execute_single_player_draw_card(socket) do
    Game.draw_card(socket.assigns.game, socket.assigns.player_id)
  end

  defp execute_single_player_nominate_suit(socket, suit) do
    Game.nominate_suit(socket.assigns.game, socket.assigns.player_id, suit)
  end

  # Helper functions

  defp convert_indices_to_cards(hand, card_indices) do
    card_indices
    |> Enum.map(fn index -> Enum.at(hand, index) end)
    |> Enum.reject(&is_nil/1)
  end

  defp current_player(%Game{} = game) do
    Game.current_player(game)
  end

  defp current_player(_), do: nil

  @doc """
  Formats error messages for game actions.
  """
  def format_error(:not_your_turn), do: "It's not your turn!"
  def format_error(:must_play_valid_card), do: "You must play a valid card!"
  def format_error(:invalid_play), do: "Invalid play!"
  def format_error(:first_card_invalid), do: "The first card doesn't match the current card!"
  def format_error(:must_play_pickup_card), do: "You must play a 2 or black jack!"
  def format_error(:must_play_twos), do: "You must play 2s to continue the stack!"
  def format_error(:must_play_jacks), do: "You must play Jacks to counter black jacks!"
  def format_error(:must_play_nominated_suit), do: "You must play the nominated suit!"
  def format_error(:can_only_stack_same_rank), do: "You can only stack cards of the same rank!"
  def format_error(:game_not_found), do: "Game connection lost. Please return to lobby."
  def format_error(:timeout), do: "Game server is not responding. Please try again."
  def format_error(:player_not_found), do: "Player not found in game."
  def format_error(:cards_not_in_hand), do: "Selected cards are not in your hand."
  def format_error(:no_ace_played), do: "No ace was played, suit nomination not needed."
  def format_error(:not_host), do: "Only the host can start the game."
  def format_error({:server_error, _reason}), do: "Server error occurred. Please try again."
  def format_error(error), do: "Error: #{inspect(error)}"
end
