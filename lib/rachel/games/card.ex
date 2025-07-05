defmodule Rachel.Games.Card do
  @moduledoc """
  Represents a playing card with suit and rank.
  Handles card display and comparison logic.
  """

  @type suit :: :hearts | :diamonds | :clubs | :spades
  @type rank :: 2..10 | :jack | :queen | :king | :ace
  @type t :: %__MODULE__{
          suit: suit(),
          rank: rank()
        }

  defstruct [:suit, :rank]

  @suits [:hearts, :diamonds, :clubs, :spades]
  @ranks [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace]

  @spec new(suit(), rank()) :: t()
  def new(suit, rank) when suit in @suits and rank in @ranks do
    %__MODULE__{suit: suit, rank: rank}
  end

  @spec suits() :: [suit()]
  def suits, do: @suits

  @spec ranks() :: [rank()]
  def ranks, do: @ranks

  @spec black_jack?(t()) :: boolean()
  def black_jack?(%__MODULE__{rank: :jack, suit: suit}) when suit in [:clubs, :spades], do: true
  def black_jack?(_), do: false

  @spec red_jack?(t()) :: boolean()
  def red_jack?(%__MODULE__{rank: :jack, suit: suit}) when suit in [:hearts, :diamonds], do: true
  def red_jack?(_), do: false

  @spec special_effect(t()) ::
          :pickup_two | :skip_turn | :jack_effect | :reverse_direction | :choose_suit | nil
  def special_effect(%__MODULE__{rank: rank}) do
    case rank do
      2 -> :pickup_two
      7 -> :skip_turn
      :jack -> :jack_effect
      :queen -> :reverse_direction
      :ace -> :choose_suit
      _ -> nil
    end
  end

  @spec matches_suit?(t(), t()) :: boolean()
  def matches_suit?(%__MODULE__{suit: suit1}, %__MODULE__{suit: suit2}), do: suit1 == suit2

  @spec matches_rank?(t(), t()) :: boolean()
  def matches_rank?(%__MODULE__{rank: rank1}, %__MODULE__{rank: rank2}), do: rank1 == rank2

  @spec can_play_on?(t(), t()) :: boolean()
  def can_play_on?(%__MODULE__{} = card, %__MODULE__{} = top_card) do
    matches_suit?(card, top_card) or matches_rank?(card, top_card) or card.rank == :ace
  end

  @spec display(t()) :: String.t()
  def display(%__MODULE__{suit: suit, rank: rank}) do
    "#{format_rank(rank)}#{suit_symbol(suit)}"
  end

  defp format_rank(rank) when is_integer(rank), do: to_string(rank)
  defp format_rank(:jack), do: "J"
  defp format_rank(:queen), do: "Q"
  defp format_rank(:king), do: "K"
  defp format_rank(:ace), do: "A"

  defp suit_symbol(:hearts), do: "♥"
  defp suit_symbol(:diamonds), do: "♦"
  defp suit_symbol(:clubs), do: "♣"
  defp suit_symbol(:spades), do: "♠"
end
