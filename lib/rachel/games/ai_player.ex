defmodule Rachel.Games.AIPlayer do
  @moduledoc """
  AI logic for computer-controlled Rachel players.
  Implements basic strategy for playing cards.
  """
  
  alias Rachel.Games.{Game, Card}

  def make_move(%Game{} = game, player_id) do
    player = Game.current_player(game)
    
    if player && player.id == player_id do
      valid_plays = Game.get_valid_plays(game, player)
      
      if Enum.empty?(valid_plays) do
        # Must draw
        {:draw, nil}
      else
        # Choose best card to play
        {_card, index} = choose_best_play(game, valid_plays)
        {:play, index}
      end
    else
      {:error, :not_ai_turn}
    end
  end

  defp choose_best_play(game, valid_plays) do
    # Priority order:
    # 1. Counter black jacks with red jacks
    # 2. Play defensive cards when under attack
    # 3. Play offensive cards when opponents have many cards
    # 4. Play regular cards
    
    plays_by_priority = Enum.group_by(valid_plays, fn {card, _index} ->
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
      Card.red_jack?(card) -> 100  # Highest priority - defend!
      Card.black_jack?(card) -> 90  # Pass it on
      true -> 0                     # Can't play regular cards
    end
  end

  defp calculate_priority(%Game{pending_pickup_type: :twos}, card) do
    # Under 2s attack
    if card.rank == 2 do
      85  # Continue the attack
    else
      0   # Can't play
    end
  end

  defp calculate_priority(game, card) do
    opponents_with_many_cards = count_opponents_with_many_cards(game)
    
    case Card.special_effect(card) do
      :pickup_two when opponents_with_many_cards == 0 -> 70
      :skip_turn when opponents_with_many_cards == 0 -> 65
      :jack_effect ->
        if Card.black_jack?(card) && opponents_with_many_cards == 0 do
          75
        else
          30  # Save red jacks for defense
        end
      :reverse_direction when length(game.players) > 2 -> 60
      :choose_suit -> 50
      _ -> 40  # Regular cards
    end
  end

  defp count_opponents_with_many_cards(%Game{players: players, current_player_index: current}) do
    players
    |> Enum.with_index()
    |> Enum.count(fn {player, idx} ->
      idx != current && length(player.hand) <= 3
    end)
  end

end