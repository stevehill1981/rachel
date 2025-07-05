defmodule Rachel.Games.Commentary do
  @moduledoc """
  Live game commentary system that provides narrative descriptions of game events.
  """

  @type comment_type :: :play | :draw | :skip | :reverse | :effect | :win | :join | :disconnect

  @doc """
  Generates live commentary for various game events.
  """
  @spec generate_comment(comment_type(), map()) :: String.t()
  def generate_comment(:play, %{player: player, cards: cards, special_effects: effects}) do
    card_text = format_cards_played(cards)
    base_comment = "#{player.name} plays #{card_text}"

    case effects do
      [] -> base_comment <> "."
      effects -> base_comment <> " - " <> format_special_effects(effects) <> "!"
    end
  end

  def generate_comment(:draw, %{player: player, count: count, reason: reason}) do
    reason_text =
      case reason do
        :forced -> "is forced to draw"
        :no_valid_play -> "has no valid plays and draws"
        :choice -> "chooses to draw"
      end

    card_word = if count == 1, do: "card", else: "cards"
    "#{player.name} #{reason_text} #{count} #{card_word}."
  end

  def generate_comment(:skip, %{player: player, count: count}) do
    turn_word = if count == 1, do: "turn", else: "turns"
    "#{player.name} is skipped for #{count} #{turn_word}!"
  end

  def generate_comment(:reverse, %{direction: direction}) do
    direction_text = if direction == :clockwise, do: "clockwise", else: "counter-clockwise"
    "Play direction reverses to #{direction_text}!"
  end

  def generate_comment(:effect, %{effect: effect, details: details}) do
    case effect do
      :suit_nomination ->
        "#{details.player} nominates #{format_suit(details.suit)} suit!"

      :pickup_stack ->
        "#{details.count} pickup cards are stacked - next player must draw or counter!"

      :skip_stack ->
        "#{details.count} skip effects are stacked!"

      :counter_play ->
        "#{details.player} counters with a #{format_card(details.card)}!"
    end
  end

  def generate_comment(:win, %{player: player, position: position, total_players: total}) do
    case position do
      1 -> "🎉 #{player.name} wins the game! Excellent strategy!"
      2 -> "#{player.name} finishes in 2nd place - well played!"
      ^total -> "#{player.name} finishes last, but every game is a learning experience!"
      _ -> "#{player.name} finishes in position #{position}."
    end
  end

  def generate_comment(:join, %{player: player, type: :spectator}) do
    "👀 #{player.name} joins as a spectator."
  end

  def generate_comment(:join, %{player: player, type: :player}) do
    "🎮 #{player.name} joins the game!"
  end

  def generate_comment(:disconnect, %{player: player}) do
    "📵 #{player.name} has disconnected."
  end

  @doc """
  Generates strategic commentary based on game state analysis.
  """
  @spec generate_strategic_comment(map()) :: String.t() | nil
  def generate_strategic_comment(game) do
    cond do
      low_card_warning(game) ->
        player = find_low_card_player(game)
        "⚠️ #{player.name} is down to #{length(player.hand)} cards!"

      high_pickup_stack(game) ->
        "💀 #{game.pending_pickups} pickup cards stacked - this could be devastating!"

      close_game(game) ->
        "🔥 This game is heating up - multiple players close to winning!"

      ai_strategic_play(game) ->
        "🤖 Smart play by the AI - that move could change everything!"

      true ->
        nil
    end
  end

  @doc """
  Generates excitement level based on current game state.
  """
  @spec get_excitement_level(map()) :: :low | :medium | :high | :extreme
  def get_excitement_level(game) do
    total_excitement = calculate_excitement_score(game)
    
    cond do
      total_excitement <= 1 -> :low
      total_excitement <= 3 -> :medium
      total_excitement <= 5 -> :high
      true -> :extreme
    end
  end
  
  defp calculate_excitement_score(game) do
    excitement_factors = [
      {game.pending_pickups > 5, 2},
      {game.pending_skips > 2, 1},
      {close_game(game), 3},
      {multiple_low_cards(game), 2},
      {game.direction == :counter_clockwise, 1}
    ]
    
    excitement_factors
    |> Enum.filter(fn {condition, _} -> condition end)
    |> Enum.map(fn {_, score} -> score end)
    |> Enum.sum()
  end

  # Private helper functions

  defp format_cards_played([card]), do: format_card(card)

  defp format_cards_played(cards) do
    count = length(cards)
    first_card = List.first(cards)
    "#{count} #{format_rank(first_card.rank)}s"
  end

  defp format_card(card) do
    "#{format_rank(card.rank)} of #{format_suit(card.suit)}"
  end

  defp format_rank(:ace), do: "Ace"
  defp format_rank(:king), do: "King"
  defp format_rank(:queen), do: "Queen"
  defp format_rank(:jack), do: "Jack"
  defp format_rank(rank) when is_integer(rank), do: to_string(rank)

  defp format_suit(:hearts), do: "Hearts ♥"
  defp format_suit(:diamonds), do: "Diamonds ♦"
  defp format_suit(:clubs), do: "Clubs ♣"
  defp format_suit(:spades), do: "Spades ♠"

  defp format_special_effects(effects) do
    Enum.map_join(effects, ", ", &format_special_effect/1)
  end

  defp format_special_effect({:pickup, count}), do: "+#{count} cards"
  defp format_special_effect({:skip, count}), do: "skip #{count}"
  defp format_special_effect(:reverse), do: "reverse direction"
  defp format_special_effect({:nominate, suit}), do: "nominate #{format_suit(suit)}"

  defp low_card_warning(game) do
    Enum.any?(game.players, &(length(&1.hand) <= 2 and length(&1.hand) > 0))
  end

  defp find_low_card_player(game) do
    Enum.find(game.players, &(length(&1.hand) <= 2 and length(&1.hand) > 0))
  end

  defp high_pickup_stack(game), do: game.pending_pickups >= 6

  defp close_game(game) do
    low_card_players = Enum.count(game.players, &(length(&1.hand) <= 3))
    low_card_players >= 2
  end

  defp multiple_low_cards(game) do
    low_card_players = Enum.count(game.players, &(length(&1.hand) <= 2))
    low_card_players >= 2
  end

  defp ai_strategic_play(_game) do
    # This could analyze the last move to determine if it was particularly strategic
    # For now, randomly return true 20% of the time for AI moves
    :rand.uniform(10) <= 2
  end
end
