defmodule Rachel.Games.GameSequenceIntegrationTest do
  @moduledoc """
  Integration tests for multi-turn sequences and state persistence.
  These tests verify that complex game flows work correctly.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "multi-turn sequences" do
    test "complete stacking sequence with multiple players" do
      # Set up a 3-player game for stacking
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false) 
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Set up a scenario where all players can stack 2s
      current_2 = %Card{suit: :hearts, rank: 2}
      game = %{game | current_card: current_2}

      [alice, bob, charlie] = game.players
      alice = %{alice | hand: [%Card{suit: :spades, rank: 2}, %Card{suit: :clubs, rank: 5}]}
      bob = %{bob | hand: [%Card{suit: :diamonds, rank: 2}, %Card{suit: :hearts, rank: 7}]}
      charlie = %{charlie | hand: [%Card{suit: :clubs, rank: 8}]}  # No 2s
      
      game = %{game | players: [alice, bob, charlie], current_player_index: 0}
      initial_cards = count_total_cards(game)

      # Turn 1: Alice plays her 2 (stacking)
      {:ok, game} = Game.play_card(game, "alice", [0])
      assert game.pending_pickups == 2
      assert game.current_player_index == 1  # Bob's turn

      # Turn 2: Bob also stacks with his 2
      {:ok, game} = Game.play_card(game, "bob", [0])
      assert game.pending_pickups == 4  # 2 + 2
      assert game.current_player_index == 2  # Charlie's turn

      # Turn 3: Charlie has no 2s, must draw all 4 cards
      charlie_hand_before = length(Enum.at(game.players, 2).hand)
      {:ok, game} = Game.draw_card(game, "charlie")
      charlie_hand_after = length(Enum.at(game.players, 2).hand)
      
      assert charlie_hand_after == charlie_hand_before + 4
      assert game.pending_pickups == 0
      assert game.pending_pickup_type == nil
      assert game.current_player_index == 0  # Back to Alice

      # Verify card conservation throughout the entire sequence
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "direction reversal sequence" do
      # Test multiple direction changes in a row
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.add_player("diana", "Diana", false)
      |> Game.start_game()

      # Set up queens for direction reversals
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      [alice, bob, charlie, diana] = game.players
      
      alice = %{alice | hand: [%Card{suit: :hearts, rank: :queen}]}  # Matches suit
      bob = %{bob | hand: [%Card{suit: :spades, rank: :queen}]}      # Matches rank 
      charlie = %{charlie | hand: [%Card{suit: :clubs, rank: :queen}]}   # Matches rank
      diana = %{diana | hand: [%Card{suit: :diamonds, rank: 5}]}     # Matches rank
      
      game = %{game | players: [alice, bob, charlie, diana], current_player_index: 0}
      initial_cards = count_total_cards(game)

      # Start clockwise
      assert game.direction == :clockwise

      # Turn 1: Alice plays Queen (reverses to counterclockwise)
      {:ok, game} = Game.play_card(game, "alice", [0])
      assert game.direction == :counterclockwise
      # Should go to Diana (counterclockwise from Alice)
      assert game.current_player_index == 3

      # Turn 2: Diana plays normal card
      {:ok, game} = Game.play_card(game, "diana", [0])
      # Should go to Charlie (continuing counterclockwise)
      assert game.current_player_index == 2

      # Turn 3: Charlie plays Queen (reverses back to clockwise)
      {:ok, game} = Game.play_card(game, "charlie", [0])
      assert game.direction == :clockwise
      # Should go to Diana (clockwise from Charlie)
      assert game.current_player_index == 3

      # Verify cards conserved through direction changes
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "ace nomination sequence" do
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up ace play
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      [alice, bob] = game.players
      
      alice = %{alice | hand: [%Card{suit: :hearts, rank: :ace}]}  # Matches suit
      bob = %{bob | hand: [%Card{suit: :clubs, rank: 7}, %Card{suit: :diamonds, rank: 8}]}
      
      game = %{game | players: [alice, bob], current_player_index: 0}
      initial_cards = count_total_cards(game)

      # Turn 1: Alice plays Ace
      {:ok, game} = Game.play_card(game, "alice", [0])
      assert game.nominated_suit == :pending
      # Turn should NOT advance yet
      assert game.current_player_index == 0

      # Alice nominates clubs
      {:ok, game} = Game.nominate_suit(game, "alice", :clubs)
      assert game.nominated_suit == :clubs
      # NOW turn should advance
      assert game.current_player_index == 1

      # Turn 2: Bob must play clubs or ace
      # Bob has clubs 7, so that should be valid
      valid_plays = Game.get_valid_plays(game, Enum.at(game.players, 1))
      valid_cards = Enum.map(valid_plays, fn {card, _} -> card end)
      
      clubs_card = Enum.find(valid_cards, fn card -> card.suit == :clubs end)
      assert clubs_card != nil
      assert clubs_card.rank == 7

      # Bob plays the clubs 7
      {:ok, game} = Game.play_card(game, "bob", [0])
      # Nomination should be cleared after playing matching suit
      assert game.nominated_suit == nil

      # Verify card conservation
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "skip chain sequence" do
      # Test multiple 7s creating skip chains
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Set up 7s for skipping
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      [alice, bob, charlie] = game.players
      
      alice = %{alice | hand: [%Card{suit: :hearts, rank: 7}]}  # Matches suit
      bob = %{bob | hand: [%Card{suit: :spades, rank: 7}]}      # Can play if gets turn
      charlie = %{charlie | hand: [%Card{suit: :clubs, rank: 5}]}  # Matches rank
      
      game = %{game | players: [alice, bob, charlie], current_player_index: 0}
      initial_cards = count_total_cards(game)

      # Turn 1: Alice plays 7 (creates skip effect)
      {:ok, game} = Game.play_card(game, "alice", [0])
      # The 7 should create a skip effect and advance the turn
      # Since we have pending skips, the next player might be skipped
      assert game.current_player_index == 2  # Should skip Bob and go to Charlie

      # Turn 2: Charlie plays normal card
      {:ok, game} = Game.play_card(game, "charlie", [0])
      # Should continue normally
      assert game.current_player_index == 0  # Back to Alice

      # Verify card conservation
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end
  end

  describe "edge case sequences" do
    test "player wins during stacking sequence" do
      # Test what happens when a player wins while stacks are pending
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up Alice to win with her last card (a 2)
      game = %{game | current_card: %Card{suit: :hearts, rank: 2}}
      [alice, bob] = game.players
      
      alice = %{alice | hand: [%Card{suit: :spades, rank: 2}]}  # Last card - will win
      bob = %{bob | hand: [%Card{suit: :clubs, rank: 5}, %Card{suit: :diamonds, rank: 8}]}
      
      game = %{game | players: [alice, bob], current_player_index: 0}
      initial_cards = count_total_cards(game)

      # Alice plays her last card
      {:ok, game} = Game.play_card(game, "alice", [0])
      
      # Alice should win
      assert "alice" in game.winners
      assert length(Enum.at(game.players, 0).hand) == 0

      # But game might continue if only 2 players (Bob becomes loser)
      # Verify card conservation regardless
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "complex multi-effect sequence" do
      # Test a sequence involving multiple special effects
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Set up a complex scenario: Queen → 7 → 2 sequence
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      [alice, bob, charlie] = game.players
      
      alice = %{alice | hand: [%Card{suit: :hearts, rank: :queen}]}  # Reverse (matches suit)
      bob = %{bob | hand: [%Card{suit: :spades, rank: 7}]}           # Skip 
      charlie = %{charlie | hand: [%Card{suit: :clubs, rank: 5}]}   # Matches rank
      
      game = %{game | players: [alice, bob, charlie], current_player_index: 0}
      initial_cards = count_total_cards(game)

      # Turn 1: Alice plays Queen (reverses direction)
      {:ok, game} = Game.play_card(game, "alice", [0])
      assert game.direction == :counterclockwise
      # Should go to Charlie (counterclockwise)
      assert game.current_player_index == 2

      # Turn 2: Charlie plays normal card
      {:ok, game} = Game.play_card(game, "charlie", [0])
      # Should go to Bob (continuing counterclockwise)
      assert game.current_player_index == 1

      # Turn 3: Bob can play if he has matching card
      # This is just testing the flow, not specific effects
      if Game.has_valid_play?(game, Enum.at(game.players, 1)) do
        {:ok, game} = Game.play_card(game, "bob", [0])
      else
        {:ok, game} = Game.draw_card(game, "bob")
      end

      # Verify card conservation through complex effects
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end
  end

  # Helper function
  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end