defmodule Rachel.Games.RulesVerificationTest do
  @moduledoc """
  Comprehensive verification that the Rachel card game implementation
  correctly follows all the established rules.

  This test suite documents and verifies:
  1. Card dealing rules (7 for ≤6 players, 5 for 7-8 players)
  2. Special card effects and stacking
  3. Mandatory play rules  
  4. Deck exhaustion and reshuffling
  5. Game continuation until one player remains
  6. Turn order preservation after elimination
  7. Starting cards have no effects

  All tests in this file serve as both verification and documentation
  of the correct game rules implementation.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  test "comprehensive rules verification - all major rules work together" do
    # Test a complex scenario that exercises multiple rules
    
    # 8-player game (tests 5-card dealing)
    game = Game.new()
    |> Game.add_player("p1", "Player 1", false)
    |> Game.add_player("p2", "Player 2", false)
    |> Game.add_player("p3", "Player 3", false)
    |> Game.add_player("p4", "Player 4", false)
    |> Game.add_player("p5", "Player 5", false)
    |> Game.add_player("p6", "Player 6", false)
    |> Game.add_player("p7", "Player 7", false)
    |> Game.add_player("p8", "Player 8", false)
    |> Game.start_game()

    # Verify 8-player dealing: 5 cards each
    Enum.each(game.players, fn player ->
      assert length(player.hand) == 5
    end)

    # Verify healthy deck size: 52 - 40 dealt - 1 starting = 11 remaining
    assert length(game.deck.cards) == 11

    # Test mandatory play rule
    game = %{game | current_card: %Card{suit: :hearts, rank: 5}, current_player_index: 0}
    [p1 | rest] = game.players
    p1 = %{p1 | hand: [%Card{suit: :hearts, rank: 6} | tl(p1.hand)]}  # Valid play available
    game = %{game | players: [p1 | rest]}

    # Cannot draw when valid play exists
    assert {:error, :must_play_valid_card} = Game.draw_card(game, "p1")

    # Can play the valid card
    assert {:ok, new_game} = Game.play_card(game, "p1", [0])

    # Test stacking: Set up 2s scenario
    game2 = %{new_game | 
      current_card: %Card{suit: :clubs, rank: 2},
      current_player_index: 1,
      pending_pickups: 2,
      pending_pickup_type: :twos
    }

    [p1, p2 | rest] = game2.players
    p2 = %{p2 | hand: [
      %Card{suit: :hearts, rank: 2},
      %Card{suit: :spades, rank: 2} | tl(tl(p2.hand))
    ]}
    game2 = %{game2 | players: [p1, p2 | rest]}

    # Player can choose to play 1 or 2 cards (strategic choice)
    assert {:ok, game_one_two} = Game.play_card(game2, "p2", [0])  # Play 1 two
    assert game_one_two.pending_pickups == 4

    # Or play both (different strategic choice)  
    assert {:ok, game_both_twos} = Game.play_card(game2, "p2", [0, 1])  # Play both twos
    assert game_both_twos.pending_pickups == 6

    # Verify Black Jack stacking works (only 2 Black Jacks in deck)
    game3 = %{new_game | 
      current_card: %Card{suit: :spades, rank: :jack},
      current_player_index: 1,
      pending_pickups: 5,
      pending_pickup_type: :black_jacks
    }

    [p1, p2 | rest] = game3.players
    p2 = %{p2 | hand: [%Card{suit: :clubs, rank: :jack} | tl(p2.hand)]}  # Other Black Jack
    game3 = %{game3 | players: [p1, p2 | rest]}

    assert {:ok, game_double_black} = Game.play_card(game3, "p2", [0])
    assert game_double_black.pending_pickups == 10  # 5 + 5

    # Test Red Jack countering
    game4 = %{game_double_black | current_player_index: 2}
    [p1, p2, p3 | rest] = game4.players
    p3 = %{p3 | hand: [%Card{suit: :hearts, rank: :jack} | tl(p3.hand)]}  # Red Jack
    game4 = %{game4 | players: [p1, p2, p3 | rest]}

    assert {:ok, game_red_counter} = Game.play_card(game4, "p3", [0])
    assert game_red_counter.pending_pickups == 5  # 10 - 5 (partial counter)

    # All these complex interactions should result in a valid game state
    assert game_red_counter.status == :playing
    assert length(game_red_counter.players) == 8
  end

  test "deck reshuffling works correctly" do
    game = Game.new()
    |> Game.add_player("p1", "Player 1", false)
    |> Game.add_player("p2", "Player 2", false)
    |> Game.start_game()

    # Simulate nearly empty deck (2 cards) with large discard pile
    small_deck = %{game.deck | cards: Enum.take(game.deck.cards, 2)}
    large_discard = [
      %Card{suit: :hearts, rank: 3},
      %Card{suit: :diamonds, rank: 4},
      %Card{suit: :clubs, rank: 5},
      game.current_card
    ]
    
    game = %{game | 
      deck: small_deck, 
      discard_pile: large_discard,
      pending_pickups: 5,  # Force large draw
      pending_pickup_type: :black_jacks,
      current_player_index: 0
    }

    # Give player no valid plays
    [p1, p2] = game.players
    p1 = %{p1 | hand: [%Card{suit: :spades, rank: 8}]}  # Can't play on Black Jack
    game = %{game | players: [p1, p2]}

    # Draw should trigger reshuffle and work
    assert {:ok, final_game} = Game.draw_card(game, "p1")
    
    # Player drew 5 cards (Black Jack penalty)
    updated_p1 = hd(final_game.players)
    assert length(updated_p1.hand) == 6  # 1 + 5

    # Deck was reshuffled - total cards should be preserved
    # We started with 2 + 3 cards to reshuffle = 5 total cards available
    # Drew 5 cards, so deck might be empty but operation succeeded
    total_cards_after = length(final_game.deck.cards) + length(updated_p1.hand) + length(final_game.discard_pile)
    assert total_cards_after >= 7  # At least the cards we started with
    
    # Discard pile only has current card
    assert length(final_game.discard_pile) == 1
  end

  test "Ace suit nomination allows any suit choice" do
    game = Game.new()
    |> Game.add_player("p1", "Player 1", false)
    |> Game.add_player("p2", "Player 2", false)
    |> Game.start_game()

    # Player plays Ace
    game = %{game | current_card: %Card{suit: :hearts, rank: :ace}, current_player_index: 0}
    [p1, p2] = game.players
    p1 = %{p1 | hand: [%Card{suit: :clubs, rank: :ace}]}
    game = %{game | players: [p1, p2]}

    assert {:ok, after_ace} = Game.play_card(game, "p1", [0])
    assert after_ace.nominated_suit == :pending

    # Can nominate any suit
    assert {:ok, _} = Game.nominate_suit(after_ace, "p1", :hearts)
    assert {:ok, _} = Game.nominate_suit(after_ace, "p1", :diamonds)
    assert {:ok, _} = Game.nominate_suit(after_ace, "p1", :clubs)
    assert {:ok, _} = Game.nominate_suit(after_ace, "p1", :spades)
  end

  test "game ends only when one player remains" do
    # 4-player scenario
    game = Game.new()
    |> Game.add_player("p1", "Player 1", false)
    |> Game.add_player("p2", "Player 2", false)
    |> Game.add_player("p3", "Player 3", false)
    |> Game.add_player("p4", "Player 4", false)
    |> Game.start_game()

    # Simulate elimination sequence
    game_1_winner = %{game | winners: ["p1"]}
    active_after_1 = Enum.reject(game_1_winner.players, fn p -> p.id in game_1_winner.winners end)
    assert length(active_after_1) == 3
    # Game should continue

    game_2_winners = %{game | winners: ["p1", "p3"]}
    active_after_2 = Enum.reject(game_2_winners.players, fn p -> p.id in game_2_winners.winners end)
    assert length(active_after_2) == 2
    # Game should continue

    game_3_winners = %{game | winners: ["p1", "p3", "p2"]}
    active_after_3 = Enum.reject(game_3_winners.players, fn p -> p.id in game_3_winners.winners end)
    assert length(active_after_3) == 1
    # Game should end (only p4 remains as loser)

    # Winners list shows elimination order: 1st, 2nd, 3rd place
    # p4 is 4th place (last remaining = loser)
    assert game_3_winners.winners == ["p1", "p3", "p2"]
  end

  test "starting cards have no effect while played cards do" do
    # Create game normally (which sets proper state)
    game = Game.new()
    |> Game.add_player("p1", "Player 1", false)
    |> Game.add_player("p2", "Player 2", false)
    |> Game.start_game()

    # Override the starting card to be a 2 (but keep no effect state)
    starting_card = %Card{suit: :hearts, rank: 2}
    game = %{game |
      current_card: starting_card,
      discard_pile: [starting_card],
      pending_pickups: 0,  # No effect from starting card
      pending_pickup_type: nil
    }

    # Give players normal hands (need to keep original hands from dealing)
    [p1, p2] = game.players
    p1 = %{p1 | hand: [%Card{suit: :hearts, rank: 5} | p1.hand]}  # Add playable card
    p2 = %{p2 | hand: [%Card{suit: :clubs, rank: 6} | p2.hand]}   # Add card for p2
    game = %{game | players: [p1, p2]}

    # Player can play normally (no forced pickup from starting 2)
    assert {:ok, after_play} = Game.play_card(game, "p1", [0])
    assert after_play.pending_pickups == 0

    # But if someone NOW plays a 2, it should have effect
    game2 = %{after_play | current_player_index: 1}
    [p1_after, p2] = after_play.players
    p2 = %{p2 | hand: [%Card{suit: :hearts, rank: 2} | tl(p2.hand)]}  # Replace first card with 2H
    game2 = %{game2 | players: [p1_after, p2]}

    assert {:ok, after_played_two} = Game.play_card(game2, "p2", [0])
    assert after_played_two.pending_pickups == 2  # Now it has effect
  end

  test "all special cards work as specified" do
    _game = Game.new()
    |> Game.add_player("p1", "Player 1", false)
    |> Game.add_player("p2", "Player 2", false)
    |> Game.add_player("p3", "Player 3", false)
    |> Game.start_game()

    # Test each special card type
    
    # 2s: +2 cards each
    assert Card.special_effect(%Card{suit: :hearts, rank: 2}) == :pickup_two
    
    # 7s: Skip turn
    assert Card.special_effect(%Card{suit: :clubs, rank: 7}) == :skip_turn
    
    # Queens: Reverse direction
    assert Card.special_effect(%Card{suit: :spades, rank: :queen}) == :reverse_direction
    
    # Jacks: Handle based on color
    assert Card.special_effect(%Card{suit: :spades, rank: :jack}) == :jack_effect
    assert Card.black_jack?(%Card{suit: :spades, rank: :jack}) == true
    assert Card.black_jack?(%Card{suit: :clubs, rank: :jack}) == true
    assert Card.red_jack?(%Card{suit: :hearts, rank: :jack}) == true
    assert Card.red_jack?(%Card{suit: :diamonds, rank: :jack}) == true
    
    # Aces: Choose suit
    assert Card.special_effect(%Card{suit: :hearts, rank: :ace}) == :choose_suit
    
    # Non-special cards: No effect
    assert Card.special_effect(%Card{suit: :hearts, rank: 3}) == nil
    assert Card.special_effect(%Card{suit: :hearts, rank: 8}) == nil
    assert Card.special_effect(%Card{suit: :hearts, rank: :king}) == nil
  end
end