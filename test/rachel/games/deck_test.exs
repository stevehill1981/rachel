defmodule Rachel.Games.DeckTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Deck}

  describe "new/0" do
    test "creates a standard 52-card deck" do
      deck = Deck.new()
      
      assert %Deck{} = deck
      assert length(deck.cards) == 52
      assert deck.discarded == []
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

    test "draws all remaining cards when requested more than available" do
      deck = Deck.new()
      # Keep only 3 cards
      deck = %{deck | cards: Enum.take(deck.cards, 3)}
      
      {drawn, new_deck} = Deck.draw(deck, 5)
      
      assert length(drawn) == 3
      assert new_deck.cards == []
    end

    test "draws zero cards returns empty list" do
      deck = Deck.new()
      
      {drawn, new_deck} = Deck.draw(deck, 0)
      
      assert drawn == []
      assert new_deck == deck
    end
  end

  describe "draw_one/1" do
    test "draws exactly one card" do
      deck = Deck.new()
      [expected_card | rest] = deck.cards
      
      {card, new_deck} = Deck.draw_one(deck)
      
      assert card == expected_card
      assert new_deck.cards == rest
    end

    test "returns nil when deck is empty" do
      deck = %Deck{cards: [], discarded: []}
      
      {card, new_deck} = Deck.draw_one(deck)
      
      assert card == nil
      assert new_deck.cards == []
    end
  end

  describe "add_to_discard/2" do
    test "adds card to discard pile" do
      deck = Deck.new()
      card = Card.new(:hearts, :king)
      
      new_deck = Deck.add_to_discard(deck, card)
      
      assert card in new_deck.discarded
      assert length(new_deck.discarded) == 1
      # Original cards unchanged
      assert new_deck.cards == deck.cards
    end

    test "preserves order - newest cards first" do
      deck = Deck.new()
      card1 = Card.new(:hearts, :king)
      card2 = Card.new(:spades, :ace)
      
      deck = deck
        |> Deck.add_to_discard(card1)
        |> Deck.add_to_discard(card2)
      
      assert deck.discarded == [card2, card1]
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
      deck = %Deck{cards: [], discarded: []}
      assert Deck.size(deck) == 0
      assert deck.cards == []
    end

    test "deck is not empty when cards remain" do
      deck = Deck.new()
      assert Deck.size(deck) > 0
      assert deck.cards != []
      
      deck = %Deck{cards: [Card.new(:hearts, :king)], discarded: []}
      assert Deck.size(deck) == 1
    end
  end


  describe "integration scenarios" do
    test "drawing from empty deck returns empty list" do
      deck = %Deck{cards: [], discarded: []}
      
      {drawn, new_deck} = Deck.draw(deck, 5)
      
      assert drawn == []
      assert new_deck.cards == []
    end

    test "deck maintains card conservation" do
      deck = Deck.new()
      
      # Draw some cards
      {drawn, deck} = Deck.draw(deck, 10)
      
      # Add some to discard
      deck = Enum.reduce(Enum.take(drawn, 5), deck, fn card, d ->
        Deck.add_to_discard(d, card)
      end)
      
      # Total cards should still be 52
      total = length(deck.cards) + length(deck.discarded) + 5  # 5 cards not discarded
      assert total == 52
    end

    test "can draw entire deck" do
      deck = Deck.new()
      
      {drawn, empty_deck} = Deck.draw(deck, 52)
      
      assert length(drawn) == 52
      assert Deck.size(empty_deck) == 0
    end
  end
end