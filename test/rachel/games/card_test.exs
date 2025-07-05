defmodule Rachel.Games.CardTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.Card

  describe "new/2" do
    test "creates a valid card" do
      card = Card.new(:hearts, :king)
      assert %Card{suit: :hearts, rank: :king} = card
    end

    test "creates numbered cards" do
      card = Card.new(:spades, 7)
      assert %Card{suit: :spades, rank: 7} = card
    end
  end

  describe "suits/0" do
    test "returns all four suits" do
      suits = Card.suits()
      assert length(suits) == 4
      assert :hearts in suits
      assert :diamonds in suits
      assert :clubs in suits
      assert :spades in suits
    end
  end

  describe "ranks/0" do
    test "returns all 13 ranks" do
      ranks = Card.ranks()
      assert length(ranks) == 13

      # Check numbered ranks
      for n <- 2..10 do
        assert n in ranks
      end

      # Check face card ranks
      assert :jack in ranks
      assert :queen in ranks
      assert :king in ranks
      assert :ace in ranks
    end
  end

  describe "can_play_on?/2" do
    test "same suit cards can play on each other" do
      current = Card.new(:hearts, :king)
      card = Card.new(:hearts, 2)
      assert Card.can_play_on?(card, current) == true
    end

    test "same rank cards can play on each other" do
      current = Card.new(:hearts, :king)
      card = Card.new(:spades, :king)
      assert Card.can_play_on?(card, current) == true
    end

    test "ace follows standard suit/rank matching rules" do
      current = Card.new(:hearts, :king)

      # Ace can play on same suit
      ace_hearts = Card.new(:hearts, :ace)
      assert Card.can_play_on?(ace_hearts, current) == true

      # Ace can play on another ace
      ace_spades = Card.new(:spades, :ace)
      current_ace = Card.new(:diamonds, :ace)
      assert Card.can_play_on?(ace_spades, current_ace) == true

      # Ace cannot play on different suit/rank
      ace_clubs = Card.new(:clubs, :ace)
      assert Card.can_play_on?(ace_clubs, current) == false
    end

    test "different suit and rank cannot play" do
      current = Card.new(:hearts, :king)
      card = Card.new(:spades, 2)
      assert Card.can_play_on?(card, current) == false
    end
  end

  describe "special_effect/1" do
    test "2s have pickup_two effect" do
      card = Card.new(:hearts, 2)
      assert Card.special_effect(card) == :pickup_two
    end

    test "7s have skip_turn effect" do
      card = Card.new(:clubs, 7)
      assert Card.special_effect(card) == :skip_turn
    end

    test "8s have no special effect" do
      card = Card.new(:diamonds, 8)
      assert Card.special_effect(card) == nil
    end

    test "jacks have jack_effect" do
      card = Card.new(:spades, :jack)
      assert Card.special_effect(card) == :jack_effect
    end

    test "aces have choose_suit effect" do
      card = Card.new(:hearts, :ace)
      assert Card.special_effect(card) == :choose_suit
    end

    test "other cards have no effect" do
      card = Card.new(:hearts, 3)
      assert Card.special_effect(card) == nil

      card = Card.new(:spades, :king)
      assert Card.special_effect(card) == nil
    end
  end

  describe "black_jack?/1" do
    test "spades jack is black jack" do
      card = Card.new(:spades, :jack)
      assert Card.black_jack?(card) == true
    end

    test "clubs jack is black jack" do
      card = Card.new(:clubs, :jack)
      assert Card.black_jack?(card) == true
    end

    test "hearts jack is not black jack" do
      card = Card.new(:hearts, :jack)
      assert Card.black_jack?(card) == false
    end

    test "diamonds jack is not black jack" do
      card = Card.new(:diamonds, :jack)
      assert Card.black_jack?(card) == false
    end

    test "non-jacks are not black jacks" do
      card = Card.new(:spades, :king)
      assert Card.black_jack?(card) == false
    end
  end

  describe "red_jack?/1" do
    test "hearts jack is red jack" do
      card = Card.new(:hearts, :jack)
      assert Card.red_jack?(card) == true
    end

    test "diamonds jack is red jack" do
      card = Card.new(:diamonds, :jack)
      assert Card.red_jack?(card) == true
    end

    test "spades jack is not red jack" do
      card = Card.new(:spades, :jack)
      assert Card.red_jack?(card) == false
    end

    test "clubs jack is not red jack" do
      card = Card.new(:clubs, :jack)
      assert Card.red_jack?(card) == false
    end

    test "non-jacks are not red jacks" do
      card = Card.new(:hearts, :queen)
      assert Card.red_jack?(card) == false
    end
  end

  describe "display/1" do
    test "formats numbered cards" do
      card = Card.new(:hearts, 7)
      assert Card.display(card) == "7♥"
    end

    test "formats face cards" do
      assert Card.display(Card.new(:spades, :jack)) == "J♠"
      assert Card.display(Card.new(:diamonds, :queen)) == "Q♦"
      assert Card.display(Card.new(:clubs, :king)) == "K♣"
      assert Card.display(Card.new(:hearts, :ace)) == "A♥"
    end

    test "formats all suits correctly" do
      assert Card.display(Card.new(:hearts, 2)) == "2♥"
      assert Card.display(Card.new(:diamonds, 2)) == "2♦"
      assert Card.display(Card.new(:clubs, 2)) == "2♣"
      assert Card.display(Card.new(:spades, 2)) == "2♠"
    end
  end

  describe "queens have reverse_direction effect" do
    test "queens reverse direction" do
      card = Card.new(:hearts, :queen)
      assert Card.special_effect(card) == :reverse_direction
    end
  end

  describe "card comparison and equality" do
    test "cards with same suit and rank are equal" do
      card1 = Card.new(:hearts, :king)
      card2 = Card.new(:hearts, :king)
      assert card1 == card2
    end

    test "cards with different suits are not equal" do
      card1 = Card.new(:hearts, :king)
      card2 = Card.new(:spades, :king)
      assert card1 != card2
    end

    test "cards with different ranks are not equal" do
      card1 = Card.new(:hearts, :king)
      card2 = Card.new(:hearts, :queen)
      assert card1 != card2
    end
  end

  describe "edge cases" do
    test "10 is a valid rank" do
      card = Card.new(:hearts, 10)
      assert card.rank == 10
      assert Card.display(card) == "10♥"
    end

    test "all combinations of suits and ranks are valid" do
      for suit <- Card.suits(), rank <- Card.ranks() do
        card = Card.new(suit, rank)
        assert %Card{suit: ^suit, rank: ^rank} = card
      end
    end
  end
end
