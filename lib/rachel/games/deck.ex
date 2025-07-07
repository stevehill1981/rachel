defmodule Rachel.Games.Deck do
  @moduledoc """
  Manages a deck of cards for the Rachel game.
  Handles shuffling, dealing, and drawing cards.
  """

  alias Rachel.Games.Card

  @type t :: %__MODULE__{
          cards: [Card.t()]
        }

  defstruct cards: []

  @spec new() :: t()
  def new do
    cards =
      for suit <- Card.suits(), rank <- Card.ranks() do
        Card.new(suit, rank)
      end

    %__MODULE__{cards: Enum.shuffle(cards)}
  end

  @spec draw(t(), non_neg_integer()) :: {[Card.t()], t()}
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

  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{cards: cards}), do: length(cards)
end
