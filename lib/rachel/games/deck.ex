defmodule Rachel.Games.Deck do
  @moduledoc """
  Manages a deck of cards for the Rachel game.
  Handles shuffling, dealing, and drawing cards.
  """

  alias Rachel.Games.Card

  @type t :: %__MODULE__{
          cards: [Card.t()],
          discarded: [Card.t()]
        }

  defstruct cards: [], discarded: []

  @spec new() :: t()
  def new do
    cards =
      for suit <- Card.suits(), rank <- Card.ranks() do
        Card.new(suit, rank)
      end

    %__MODULE__{cards: Enum.shuffle(cards), discarded: []}
  end

  @spec draw(t(), non_neg_integer()) :: {[Card.t()], t()}
  def draw(%__MODULE__{cards: []} = deck, count) do
    reshuffle_and_draw(deck, count)
  end

  def draw(%__MODULE__{cards: cards} = deck, count) when length(cards) < count do
    # Try to reshuffle first, but if no discarded cards, return what we have
    case reshuffle_and_draw(deck, count) do
      {[], _deck} ->
        # No discarded cards to reshuffle, return all available cards
        {cards, %{deck | cards: []}}

      result ->
        result
    end
  end

  def draw(%__MODULE__{cards: cards} = deck, count) do
    {drawn, remaining} = Enum.split(cards, count)
    {drawn, %{deck | cards: remaining}}
  end

  @spec draw_one(t()) :: {Card.t() | nil, t()}
  def draw_one(deck) do
    case draw(deck, 1) do
      {[card], new_deck} -> {card, new_deck}
      {[], new_deck} -> {nil, new_deck}
    end
  end

  @spec add_to_discard(t(), [Card.t()] | Card.t()) :: t()
  def add_to_discard(%__MODULE__{discarded: discarded} = deck, cards) when is_list(cards) do
    %{deck | discarded: cards ++ discarded}
  end

  def add_to_discard(deck, card) do
    add_to_discard(deck, [card])
  end

  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{cards: cards}), do: length(cards)

  defp reshuffle_and_draw(%__MODULE__{discarded: []} = deck, _count) do
    {[], deck}
  end

  defp reshuffle_and_draw(%__MODULE__{discarded: discarded}, count) do
    # Keep the top card of discard pile (current play card)
    [top_card | cards_to_shuffle] = Enum.reverse(discarded)

    # If no cards to shuffle, return empty
    if cards_to_shuffle == [] do
      {[], %__MODULE__{cards: [], discarded: [top_card]}}
    else
      new_deck = %__MODULE__{
        cards: Enum.shuffle(cards_to_shuffle),
        discarded: [top_card]
      }

      draw(new_deck, count)
    end
  end
end
