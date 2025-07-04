defmodule Rachel.Games.DeckMissingCoverageTest do
  @moduledoc """
  Targeted tests for the 4 missing lines in Deck module.
  """
  use ExUnit.Case, async: true
  
  alias Rachel.Games.{Card, Deck}
  
  describe "missing coverage" do
    test "add_to_discard with list of cards" do
      # Test lines 52-54
      deck = %Deck{cards: [], discarded: []}
      
      cards_list = [
        Card.new(:hearts, :king),
        Card.new(:spades, :ace)
      ]
      
      new_deck = Deck.add_to_discard(deck, cards_list)
      
      # Cards should be prepended to discard
      assert new_deck.discarded == cards_list
    end
    
    test "draw from empty deck with empty discard returns empty" do
      # Test line 63: reshuffle_and_draw when discarded is empty
      deck = %Deck{cards: [], discarded: []}
      
      {drawn, new_deck} = Deck.draw(deck, 5)
      
      assert drawn == []
      assert new_deck.cards == []
      assert new_deck.discarded == []
    end
    
    test "draw when not enough cards returns all available without reshuffle" do
      # Test lines 32-34: when no discarded cards to reshuffle
      deck = %Deck{
        cards: [Card.new(:hearts, 2), Card.new(:hearts, 3)],
        discarded: []
      }
      
      {drawn, new_deck} = Deck.draw(deck, 5)
      
      # Should return only the 2 available cards
      assert length(drawn) == 2
      assert new_deck.cards == []
    end
    
    test "reshuffle basic case" do
      # Test the basic reshuffle functionality
      # When deck is empty but discard has cards
      deck = %Deck{
        cards: [],
        discarded: [
          Card.new(:hearts, :king),
          Card.new(:spades, :ace)
        ]
      }
      
      {drawn, new_deck} = Deck.draw(deck, 1)
      
      # Should have drawn 1 card from reshuffled
      assert length(drawn) == 1
      
      # Discard should have 1 card (the other was reshuffled and drawn)
      assert length(new_deck.discarded) == 1
    end
    
    test "reshuffle with exactly one card in discard returns empty" do
      # Edge case: only one card in discard (which gets kept as current card)
      deck = %Deck{
        cards: [],
        discarded: [Card.new(:hearts, :king)]
      }
      
      {drawn, new_deck} = Deck.draw(deck, 1)
      
      # Should get no cards (the only discard card is kept)
      assert drawn == []
      assert new_deck.discarded == [Card.new(:hearts, :king)]
    end
  end
end