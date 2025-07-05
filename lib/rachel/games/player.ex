defmodule Rachel.Games.Player do
  @moduledoc """
  Represents a player in the game, either human or AI.
  """

  defstruct [
    :id,
    :name,
    :hand,
    :is_ai,
    :connected,
    :has_drawn
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          hand: list(Rachel.Games.Card.t()),
          is_ai: boolean(),
          connected: boolean(),
          has_drawn: boolean()
        }

  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(id, name, opts \\ []) do
    %__MODULE__{
      id: id,
      name: name,
      hand: Keyword.get(opts, :hand, []),
      is_ai: Keyword.get(opts, :is_ai, false),
      connected: Keyword.get(opts, :connected, true),
      has_drawn: Keyword.get(opts, :has_drawn, false)
    }
  end
end
