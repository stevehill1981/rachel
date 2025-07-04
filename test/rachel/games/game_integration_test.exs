defmodule Rachel.Games.GameIntegrationTest do
  @moduledoc """
  Integration tests that simulate complete gameplay scenarios.
  These tests catch bugs that unit tests miss by testing real game flows.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "full game simulations" do
    test "complete 2-player game from start to finish" do
      # Start a new game with 2 players
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)
      |> Game.start_game()

      # Verify initial state
      assert game.status == :playing
      assert length(game.players) == 2
      assert game.current_card != nil
      assert length(game.discard_pile) == 1

      # Track total cards throughout the game - should be 52 total
      initial_total_cards = count_total_cards(game)
      assert initial_total_cards == 52, "Expected 52 cards, got #{initial_total_cards}. Breakdown: hands=#{Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))}, deck=#{length(game.deck.cards)}, discard=#{length(game.discard_pile)}, current=1"

      # Simulate gameplay until someone wins
      {final_game, turns_played} = simulate_game_to_completion(game, 0)

      # Verify final state
      assert final_game.status == :finished
      assert length(final_game.winners) >= 1
      assert turns_played > 0
      assert turns_played < 200  # Sanity check - games shouldn't take forever

      # Most importantly: verify no cards were lost during the game
      final_total_cards = count_total_cards(final_game)
      assert final_total_cards == 52, "Cards were lost during gameplay! Started: #{initial_total_cards}, Ended: #{final_total_cards}"
    end

    test "complete 4-player game with AI players" do
      # Create a mixed human/AI game
      game = Game.new()
      |> Game.add_player("human1", "Alice", false)
      |> Game.add_player("ai1", "Bot Charlie", true)
      |> Game.add_player("human2", "Bob", false)
      |> Game.add_player("ai2", "Bot Diana", true)
      |> Game.start_game()

      assert length(game.players) == 4
      
      # Simulate complete game
      {final_game, turns_played} = simulate_game_to_completion(game, 0)

      # Verify final state
      assert final_game.status == :finished
      assert length(final_game.winners) >= 1
      assert turns_played > 0

      # Verify card conservation
      final_total_cards = count_total_cards(final_game)
      assert final_total_cards == 52
    end

    test "game with many deck reshuffles" do
      # Create a scenario that forces multiple deck reshuffles
      # Start with a small deck to force early recycling
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)

      # Create a minimal deck to force frequent reshuffling
      small_deck = %Rachel.Games.Deck{cards: [
        %Card{suit: :hearts, rank: 2},
        %Card{suit: :spades, rank: 2},
        %Card{suit: :clubs, rank: 3},
        %Card{suit: :diamonds, rank: 4},
        %Card{suit: :hearts, rank: 5}
      ]}
      
      current_card = %Card{suit: :hearts, rank: 6}
      
      game = %{game | 
        deck: small_deck,
        current_card: current_card,
        discard_pile: [current_card],
        status: :playing
      }

      # Give players starting hands from "external" cards
      [p1, p2] = game.players
      p1 = %{p1 | hand: [
        %Card{suit: :diamonds, rank: 7},
        %Card{suit: :clubs, rank: 8}
      ]}
      p2 = %{p2 | hand: [
        %Card{suit: :spades, rank: 9},
        %Card{suit: :hearts, rank: 10}
      ]}
      game = %{game | players: [p1, p2]}

      initial_cards = count_total_cards(game)

      # Force multiple draws to trigger reshuffling
      {:ok, game} = Game.draw_card(game, "player1")
      reshuffle_cards_1 = count_total_cards(game)
      assert reshuffle_cards_1 == initial_cards, "Cards lost during first reshuffle"

      # Continue playing and force more reshuffles
      game = advance_turn_to_player(game, "player2")
      {:ok, game} = Game.draw_card(game, "player2") 
      reshuffle_cards_2 = count_total_cards(game)
      assert reshuffle_cards_2 == initial_cards, "Cards lost during second reshuffle"

      # The deck should have been reshuffled and cards preserved
      assert game.current_card == current_card, "Current card should remain unchanged"
    end
  end

  describe "edge case scenarios" do
    test "complex stacking chains with multiple 2s" do
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)
      |> Game.add_player("player3", "Charlie", false)
      |> Game.start_game()

      # Set up a stacking scenario with 2s - start with pending pickups
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 2,
        pending_pickup_type: :twos
      }

      # Give each player some 2s to stack
      [p1, p2, p3] = game.players
      p1 = %{p1 | hand: [%Card{suit: :spades, rank: 2}, %Card{suit: :clubs, rank: 5}]}
      p2 = %{p2 | hand: [%Card{suit: :diamonds, rank: 2}, %Card{suit: :hearts, rank: 7}]}
      p3 = %{p3 | hand: [%Card{suit: :clubs, rank: 8}]}  # No 2s - will be forced to draw
      game = %{game | players: [p1, p2, p3], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Player 1 plays their 2, stacking
      {:ok, game} = Game.play_card(game, "player1", [0])
      assert game.pending_pickups == 4  # 2 + 2 = 4
      assert game.pending_pickup_type == :twos

      # Player 2 also stacks with their 2
      {:ok, game} = Game.play_card(game, "player2", [0])
      assert game.pending_pickups == 6  # 4 + 2 = 6
      assert game.pending_pickup_type == :twos

      # Player 3 has no 2s and must draw all 6 cards
      player3_before = Enum.at(game.players, 2)
      initial_hand_size = length(player3_before.hand)
      
      {:ok, game} = Game.draw_card(game, "player3")
      player3_after = Enum.at(game.players, 2)
      
      assert length(player3_after.hand) == initial_hand_size + 6
      assert game.pending_pickups == 0
      assert game.pending_pickup_type == nil

      # Verify no cards lost during stacking
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "black jack stacking and red jack countering" do
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)
      |> Game.add_player("player3", "Charlie", false)
      |> Game.start_game()

      # Set up black jack scenario - start with pending pickups
      game = %{game | 
        current_card: %Card{suit: :spades, rank: :jack},
        pending_pickups: 5,
        pending_pickup_type: :black_jacks
      }

      [p1, p2, p3] = game.players
      p1 = %{p1 | hand: [%Card{suit: :clubs, rank: :jack}]}     # Black jack to stack
      p2 = %{p2 | hand: [%Card{suit: :hearts, rank: :jack}]}    # Red jack to counter
      p3 = %{p3 | hand: [%Card{suit: :diamonds, rank: 5}]}      # No jacks
      game = %{game | players: [p1, p2, p3], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Player 1 plays black jack (stacking to 10 total pickup)
      {:ok, game} = Game.play_card(game, "player1", [0])
      assert game.pending_pickups == 10  # 5 + 5 = 10
      assert game.pending_pickup_type == :black_jacks

      # Player 2 counters with red jack (reduces by 5)
      {:ok, game} = Game.play_card(game, "player2", [0])
      assert game.pending_pickups == 5   # 10 - 5 = 5
      assert game.pending_pickup_type == :black_jacks

      # Player 3 must draw the remaining 5
      player3_before = Enum.at(game.players, 2)
      initial_hand_size = length(player3_before.hand)
      
      {:ok, game} = Game.draw_card(game, "player3")
      player3_after = Enum.at(game.players, 2)
      
      assert length(player3_after.hand) == initial_hand_size + 5
      assert game.pending_pickups == 0

      # Verify card conservation
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "game with direction reversals and skips" do
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)
      |> Game.add_player("player3", "Charlie", false)
      |> Game.add_player("player4", "Diana", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)
      assert game.direction == :clockwise

      # Set up a known current card and give players matching cards
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}}
      
      # Give players queens and 7s for testing
      [p1, p2, p3, p4] = game.players
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: :queen}]}  # Reverse (matches suit)
      p2 = %{p2 | hand: [%Card{suit: :spades, rank: 7}]}       # Skip
      p3 = %{p3 | hand: [%Card{suit: :clubs, rank: :queen}]}   # Reverse
      p4 = %{p4 | hand: [%Card{suit: :diamonds, rank: 5}]}     # Normal card (matches rank)
      game = %{game | players: [p1, p2, p3, p4], current_player_index: 0}

      # Player 1 plays Queen (reverses direction)
      {:ok, game} = Game.play_card(game, "player1", [0])
      assert game.direction == :counterclockwise
      # Turn should go to player 4 (counterclockwise from player 1)
      assert game.current_player_index == 3

      # Player 4 plays normal card
      {:ok, game} = Game.play_card(game, "player4", [0])
      # Next should be player 3 (continuing counterclockwise)
      assert game.current_player_index == 2

      # Player 3 plays Queen (reverses back to clockwise)
      {:ok, game} = Game.play_card(game, "player3", [0])
      assert game.direction == :clockwise
      # Turn should go to player 4 (clockwise from player 3)
      assert game.current_player_index == 3

      # Verify no cards lost during direction changes
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "ace nomination and suit changes" do
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)
      |> Game.start_game()

      [p1, p2] = game.players
      p1 = %{p1 | hand: [
        %Card{suit: :hearts, rank: :ace},
        %Card{suit: :clubs, rank: 5}
      ]}
      p2 = %{p2 | hand: [
        %Card{suit: :spades, rank: 7},    # Matches nominated suit
        %Card{suit: :diamonds, rank: 8}   # Doesn't match
      ]}
      game = %{game | players: [p1, p2], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Player 1 plays Ace
      {:ok, game} = Game.play_card(game, "player1", [0])
      assert game.nominated_suit == :pending
      # Turn shouldn't advance yet
      assert game.current_player_index == 0

      # Player 1 nominates spades
      {:ok, game} = Game.nominate_suit(game, "player1", :spades)
      assert game.nominated_suit == :spades
      # Now turn advances
      assert game.current_player_index == 1

      # Player 2 must play spades or another ace
      valid_plays = Game.get_valid_plays(game, Enum.at(game.players, 1))
      valid_cards = Enum.map(valid_plays, fn {card, _index} -> card end)
      
      # Should be able to play the 7 of spades
      assert Enum.any?(valid_cards, fn card -> card.suit == :spades and card.rank == 7 end)
      # Should NOT be able to play the 8 of diamonds
      refute Enum.any?(valid_cards, fn card -> card.suit == :diamonds and card.rank == 8 end)

      # Player 2 plays the valid spade
      {:ok, game} = Game.play_card(game, "player2", [0])
      
      # Suit nomination should be cleared after playing matching suit
      assert game.nominated_suit == nil

      # Verify card conservation
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end
  end

  describe "stress tests" do
    test "very long game simulation" do
      # Create conditions for a potentially long game
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)

      # Simulate up to 500 turns (should be more than enough for any reasonable game)
      {final_game, turns_played} = simulate_game_to_completion(game, 0, 500)

      # Game should complete
      assert final_game.status == :finished
      assert turns_played < 500, "Game took too long - possible infinite loop"

      # Verify card conservation throughout long game
      final_cards = count_total_cards(final_game)
      assert final_cards == initial_cards
    end

    test "multiple consecutive reshuffles" do
      # Create a scenario that forces many reshuffles in a row
      game = Game.new()
      |> Game.add_player("player1", "Alice", false)
      |> Game.add_player("player2", "Bob", false)

      # Start with just a few cards in deck
      tiny_deck = %Rachel.Games.Deck{cards: [
        %Card{suit: :hearts, rank: 2},
        %Card{suit: :spades, rank: 3}
      ]}
      
      current_card = %Card{suit: :clubs, rank: 4}
      discard_pile = [
        current_card,
        %Card{suit: :diamonds, rank: 5},
        %Card{suit: :hearts, rank: 6},
        %Card{suit: :spades, rank: 7}
      ]
      
      game = %{game | 
        deck: tiny_deck,
        current_card: current_card,
        discard_pile: discard_pile,
        status: :playing,
        current_player_index: 0
      }

      # Give players hands
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :clubs, rank: 8}]}
      p2 = %{p2 | hand: [%Card{suit: :diamonds, rank: 9}]}
      game = %{game | players: [p1, p2]}

      initial_cards = count_total_cards(game)

      # Force multiple draws to trigger multiple reshuffles
      {:ok, game} = Game.draw_card(game, "player1")
      cards_after_1 = count_total_cards(game)
      assert cards_after_1 == initial_cards

      game = advance_turn_to_player(game, "player2")
      {:ok, game} = Game.draw_card(game, "player2")
      cards_after_2 = count_total_cards(game)
      assert cards_after_2 == initial_cards

      game = advance_turn_to_player(game, "player1")
      {:ok, game} = Game.draw_card(game, "player1")
      cards_after_3 = count_total_cards(game)
      assert cards_after_3 == initial_cards

      # Current card should never change during reshuffles
      assert game.current_card == current_card
    end
  end

  # Helper functions
  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = if game.deck, do: length(game.deck.cards), else: 0
    cards_in_discard = length(game.discard_pile)
    # Don't double-count current card if it's already in discard pile
    current_card_count = if game.current_card && game.current_card not in game.discard_pile, do: 1, else: 0
    
    cards_in_hands + cards_in_deck + cards_in_discard + current_card_count
  end

  defp simulate_game_to_completion(game, turns_played, max_turns \\ 200) do
    cond do
      game.status == :finished ->
        {game, turns_played}
      
      turns_played >= max_turns ->
        {game, turns_played}
      
      true ->
        # Try to make a move for current player
        current_player = Game.current_player(game)
        
        case try_player_move(game, current_player.id) do
          {:ok, new_game} ->
            simulate_game_to_completion(new_game, turns_played + 1, max_turns)
          
          {:error, _} ->
            # If move fails, game might be stuck - stop simulation
            {game, turns_played}
        end
    end
  end

  defp try_player_move(game, player_id) do
    player = Enum.find(game.players, fn p -> p.id == player_id end)
    
    # Check if player has valid plays
    if Game.has_valid_play?(game, player) do
      # Try to play first valid card
      valid_plays = Game.get_valid_plays(game, player)
      case valid_plays do
        [] -> 
          # No valid plays, try to draw
          Game.draw_card(game, player_id)
        [{_card, index} | _] ->
          Game.play_card(game, player_id, [index])
      end
    else
      # Try to draw card
      case Game.draw_card(game, player_id) do
        {:ok, new_game} -> {:ok, new_game}
        {:error, :must_play_valid_card} ->
          # Player must have a valid card but we missed it, try to play any card
          if length(player.hand) > 0 do
            Game.play_card(game, player_id, [0])
          else
            {:error, :no_moves_available}
          end
        error -> error
      end
    end
  end

  defp advance_turn_to_player(game, target_player_id) do
    current_player = Game.current_player(game)
    
    if current_player.id == target_player_id do
      game
    else
      # Advance turn and try again
      players = game.players
      current_index = game.current_player_index
      next_index = rem(current_index + 1, length(players))
      new_game = %{game | current_player_index: next_index}
      advance_turn_to_player(new_game, target_player_id)
    end
  end
end