defmodule Rachel.Games.AIPlayer do
  @moduledoc """
  AI logic for computer-controlled Rachel players.
  Implements basic strategy for playing cards.
  """

  alias Rachel.Games.{Card, Game}

  def make_move(%Game{} = game, player_id) do
    case validate_ai_turn(game, player_id) do
      {:ok, player} ->
        determine_ai_action(game, player)

      :error ->
        {:error, :not_ai_turn}
    end
  end

  defp validate_ai_turn(game, player_id) do
    case Game.current_player(game) do
      nil -> :error
      player when player.id != player_id -> :error
      player -> {:ok, player}
    end
  end

  defp determine_ai_action(game, player) do
    if game.nominated_suit == :pending do
      suit = choose_best_suit(player.hand)
      {:nominate, suit}
    else
      execute_ai_turn(game, player)
    end
  end

  defp execute_ai_turn(game, player) do
    case Game.get_valid_plays(game, player) do
      [] ->
        {:draw, nil}

      valid_plays ->
        {_card, index} = choose_best_play(game, valid_plays)
        {:play, index}
    end
  end

  defp choose_best_play(game, valid_plays) do
    # Priority order:
    # 1. Counter black jacks with red jacks
    # 2. Play defensive cards when under attack
    # 3. Play offensive cards when opponents have many cards
    # 4. Play regular cards

    plays_by_priority =
      Enum.group_by(valid_plays, fn {card, _index} ->
        calculate_priority(game, card)
      end)

    # Get highest priority plays
    max_priority = plays_by_priority |> Map.keys() |> Enum.max()
    best_plays = Map.get(plays_by_priority, max_priority)

    # For now, just play one card at a time (we can add stacking later)
    Enum.random(best_plays)
  end

  defp calculate_priority(%Game{pending_pickup_type: :black_jacks}, card) do
    # Under black jack attack
    cond do
      # Highest priority - defend!
      Card.red_jack?(card) -> 100
      # Pass it on
      Card.black_jack?(card) -> 90
      # Can't play regular cards
      true -> 0
    end
  end

  defp calculate_priority(%Game{pending_pickup_type: :twos}, card) do
    # Under 2s attack
    if card.rank == 2 do
      # Continue the attack
      85
    else
      # Can't play
      0
    end
  end

  defp calculate_priority(game, card) do
    opponents_with_many_cards = count_opponents_with_many_cards(game)

    case Card.special_effect(card) do
      :pickup_two when opponents_with_many_cards == 0 ->
        70

      :skip_turn when opponents_with_many_cards == 0 ->
        65

      :jack_effect ->
        if Card.black_jack?(card) && opponents_with_many_cards == 0 do
          75
        else
          # Save red jacks for defense
          30
        end

      :reverse_direction when length(game.players) > 2 ->
        60

      :choose_suit ->
        # Lower priority - save aces for last
        30

      # Regular cards
      _ ->
        # Higher priority - prefer regular cards
        50
    end
  end

  defp count_opponents_with_many_cards(%Game{players: players, current_player_index: current}) do
    players
    |> Enum.with_index()
    |> Enum.count(fn {player, idx} ->
      idx != current && length(player.hand) <= 3
    end)
  end

  defp choose_best_suit(hand) do
    # Count cards by suit
    suit_counts =
      hand
      |> Enum.group_by(& &1.suit)
      |> Enum.map(fn {suit, cards} -> {suit, length(cards)} end)
      |> Enum.sort_by(fn {_suit, count} -> count end, :desc)

    # Choose the suit we have the most of
    case suit_counts do
      [{suit, _} | _] -> suit
      # Fallback, shouldn't happen
      [] -> :hearts
    end
  end
end
