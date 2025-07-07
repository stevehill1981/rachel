defmodule Rachel.Games.DeckTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Deck}

  describe "new/0" do
    test "creates a standard 52-card deck" do
      deck = Deck.new()

      assert %Deck{} = deck
      assert length(deck.cards) == 52
    end

    test "deck contains all unique cards" do
      deck = Deck.new()

      # Check all cards are unique
      unique_cards = Enum.uniq(deck.cards)
      assert length(unique_cards) == 52

      # Check all suits and ranks are represented
      for suit <- Card.suits(), rank <- Card.ranks() do
        assert Enum.any?(deck.cards, fn card ->
                 card.suit == suit && card.rank == rank
               end)
      end
    end

    test "deck is shuffled (not in predictable order)" do
      deck1 = Deck.new()
      deck2 = Deck.new()

      # Very unlikely two shuffled decks are identical
      # This test might fail very rarely by chance
      assert deck1.cards != deck2.cards
    end
  end

  describe "draw/2" do
    test "draws specified number of cards" do
      deck = Deck.new()
      initial_size = length(deck.cards)

      {drawn, new_deck} = Deck.draw(deck, 5)

      assert length(drawn) == 5
      assert length(new_deck.cards) == initial_size - 5

      # Drawn cards should be from top of deck
      assert drawn == Enum.take(deck.cards, 5)
    end

    test "drawing more cards than available returns all available" do
      deck = %Deck{cards: [Card.new(:hearts, :king), Card.new(:spades, :ace)]}

      {drawn, new_deck} = Deck.draw(deck, 5)

      assert length(drawn) == 2
      assert new_deck.cards == []
    end

    test "drawing from empty deck returns empty list" do
      deck = %Deck{cards: []}

      {drawn, new_deck} = Deck.draw(deck, 5)

      assert drawn == []
      assert new_deck.cards == []
    end

    test "drawing zero cards returns empty list" do
      deck = Deck.new()

      {drawn, new_deck} = Deck.draw(deck, 0)

      assert drawn == []
      assert new_deck.cards == deck.cards
    end
  end

  describe "draw_one/1" do
    test "draws one card from deck" do
      deck = Deck.new()
      initial_size = length(deck.cards)

      {card, new_deck} = Deck.draw_one(deck)

      assert %Card{} = card
      assert length(new_deck.cards) == initial_size - 1
    end

    test "returns nil when deck is empty" do
      deck = %Deck{cards: []}

      {card, new_deck} = Deck.draw_one(deck)

      assert card == nil
      assert new_deck.cards == []
    end
  end

  describe "size/1" do
    test "returns number of cards in deck" do
      deck = Deck.new()
      assert Deck.size(deck) == 52

      {_drawn, deck} = Deck.draw(deck, 10)
      assert Deck.size(deck) == 42

      deck = %{deck | cards: []}
      assert Deck.size(deck) == 0
    end
  end

  describe "checking if deck is empty" do
    test "deck is empty when no cards left" do
      deck = %Deck{cards: []}
      assert Deck.size(deck) == 0
      assert deck.cards == []
    end

    test "deck is not empty when cards remain" do
      deck = Deck.new()
      assert Deck.size(deck) > 0
      assert deck.cards != []

      deck = %Deck{cards: [Card.new(:hearts, :king)]}
      assert Deck.size(deck) == 1
    end
  end

  describe "integration scenarios" do
    test "can draw entire deck" do
      deck = Deck.new()

      {drawn, empty_deck} = Deck.draw(deck, 52)

      assert length(drawn) == 52
      assert Deck.size(empty_deck) == 0
    end

    test "drawing multiple times reduces deck size correctly" do
      deck = Deck.new()

      {_drawn1, deck} = Deck.draw(deck, 10)
      assert Deck.size(deck) == 42

      {_drawn2, deck} = Deck.draw(deck, 20)
      assert Deck.size(deck) == 22

      {_drawn3, deck} = Deck.draw(deck, 22)
      assert Deck.size(deck) == 0
    end

    test "drawing preserves card order" do
      cards = [
        Card.new(:hearts, :king),
        Card.new(:spades, :ace),
        Card.new(:clubs, 5)
      ]

      deck = %Deck{cards: cards}

      {drawn, _new_deck} = Deck.draw(deck, 2)

      assert drawn == [Card.new(:hearts, :king), Card.new(:spades, :ace)]
    end
  end
end
