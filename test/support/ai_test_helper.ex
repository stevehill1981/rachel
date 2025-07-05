defmodule Test.AITestHelper do
  @moduledoc """
  Test helpers specifically for AI player testing.

  Example usage:
      game = AITestHelper.ai_scenario(:play_ace, "ai")
      assert AITestHelper.ai_chooses_play(game, "ai", 0)
  """

  alias Rachel.Games.{AIPlayer, Card}
  alias Test.GameBuilder

  @doc "Creates a game where it's the AI's turn"
  def ai_turn_game(ai_hand, current_card \\ %Card{suit: :hearts, rank: :king}) do
    GameBuilder.human_vs_ai_game()
    |> GameBuilder.set_current_player("ai")
    |> GameBuilder.set_current_card(current_card)
    |> GameBuilder.give_cards("ai", ai_hand)
  end

  @doc "Creates specific AI test scenarios"
  def ai_scenario(:play_ace, ai_id) do
    # AI has only an ace that matches current card suit
    ai_turn_game(
      [
        GameBuilder.card({:hearts, :ace})
      ],
      GameBuilder.card({:hearts, :king})
    )
    |> GameBuilder.set_current_player(ai_id)
  end

  def ai_scenario(:prefer_non_ace, ai_id) do
    # AI has both ace and matching card - should prefer non-ace
    ai_turn_game(
      [
        # Matches suit - should choose this
        GameBuilder.card({:hearts, 3}),
        # Ace - should avoid
        GameBuilder.card({:spades, :ace})
      ],
      GameBuilder.card({:hearts, :king})
    )
    |> GameBuilder.set_current_player(ai_id)
  end

  def ai_scenario(:stack_twos, ai_id) do
    # AI can stack 2s on pending 2s
    GameBuilder.pending_twos_scenario(ai_id)
    |> GameBuilder.give_cards(ai_id, [
      # Can stack
      GameBuilder.card({:spades, 2}),
      # Can't play
      GameBuilder.card({:hearts, 3})
    ])
  end

  def ai_scenario(:no_valid_plays, ai_id) do
    # AI has no valid plays and must draw
    ai_turn_game(
      [
        GameBuilder.card({:spades, 2}),
        GameBuilder.card({:clubs, 3})
      ],
      GameBuilder.card({:hearts, :king})
    )
    |> GameBuilder.set_current_player(ai_id)
  end

  def ai_scenario(:nominate_suit, ai_id) do
    # AI needs to nominate suit after playing ace
    GameBuilder.two_player_game()
    |> GameBuilder.set_current_player(ai_id)
    |> GameBuilder.set_current_card(GameBuilder.card({:hearts, :ace}))
    |> GameBuilder.set_nominated_suit(:pending)
    |> GameBuilder.give_cards(ai_id, [
      GameBuilder.card({:spades, 2}),
      # Most common suit
      GameBuilder.card({:spades, 3}),
      GameBuilder.card({:clubs, 4})
    ])
  end

  def ai_scenario(:counter_black_jack, ai_id) do
    # AI can counter black jack with red jack
    GameBuilder.pending_black_jacks_scenario(ai_id)
    |> GameBuilder.give_cards(ai_id, [
      # Red jack cancels
      GameBuilder.card({:hearts, :jack}),
      # Can't play
      GameBuilder.card({:clubs, 2})
    ])
  end

  def ai_scenario(:skip_opponent, ai_id) do
    # AI can play 7 to skip opponent
    ai_turn_game(
      [
        # Skip card
        GameBuilder.card({:hearts, 7}),
        # Alternative
        GameBuilder.card({:hearts, 10})
      ],
      GameBuilder.card({:hearts, 3})
    )
    |> GameBuilder.set_current_player(ai_id)
  end

  @doc "Checks if AI chooses to play a specific card index"
  def ai_chooses_play?(game, ai_id, expected_index) do
    match?({:play, ^expected_index}, AIPlayer.make_move(game, ai_id))
  end

  @doc "Checks if AI chooses to draw"
  def ai_chooses_draw?(game, ai_id) do
    match?({:draw, nil}, AIPlayer.make_move(game, ai_id))
  end

  @doc "Checks if AI nominates a specific suit"
  def ai_nominates_suit?(game, ai_id, expected_suit) do
    match?({:nominate, ^expected_suit}, AIPlayer.make_move(game, ai_id))
  end

  @doc "Checks if AI returns an error"
  def ai_returns_error?(game, ai_id, expected_error) do
    match?({:error, ^expected_error}, AIPlayer.make_move(game, ai_id))
  end

  @doc "Gets the AI's move (for pattern matching in tests)"
  def ai_move(game, ai_id) do
    AIPlayer.make_move(game, ai_id)
  end

  @doc "Gets the most common suit in AI's hand (for nomination testing)"
  def most_common_suit_in_hand(game, ai_id) do
    ai_player = Enum.find(game.players, &(&1.id == ai_id))

    ai_player.hand
    |> Enum.group_by(& &1.suit)
    |> Enum.max_by(fn {_suit, cards} -> length(cards) end)
    |> elem(0)
  end

  @doc "Creates a hand with specified suit distribution for nomination testing"
  def hand_with_suits(suit_counts) do
    Enum.flat_map(suit_counts, fn {suit, count} ->
      Enum.map(2..(count + 1), fn rank ->
        GameBuilder.card({suit, rank})
      end)
    end)
  end

  @doc "Sets up an AI vs AI game for testing AI interactions"
  def ai_vs_ai_game do
    GameBuilder.new()
    |> GameBuilder.with_players([
      {"ai1", "Computer 1", true},
      {"ai2", "Computer 2", true}
    ])
    |> GameBuilder.start_game()
  end
end
