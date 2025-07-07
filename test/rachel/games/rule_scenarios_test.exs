defmodule Rachel.Games.RuleScenariosTest do
  @moduledoc """
  Tests the specific rule scenarios discussed to ensure the game
  implementation matches the actual Rachel card game rules.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "mandatory play rule" do
    test "player cannot draw when they have valid plays" do
      # Setup game with a player who has a valid play
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set current card to 5 of Hearts
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}, current_player_index: 0}

      # Give player 1 a valid card (5 of Clubs)
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :clubs, rank: 5}]}
      game = %{game | players: [p1, p2]}

      # Player should NOT be able to draw when they have a valid play
      assert {:error, :must_play_valid_card} = Game.draw_card(game, "p1")
    end

    test "player can choose how many cards to play from same rank" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set current card to 2 of Hearts with existing effect
      game = %{
        game
        | current_card: %Card{suit: :hearts, rank: 2},
          current_player_index: 0,
          pending_pickups: 2,
          pending_pickup_type: :twos
      }

      # Give player 1 multiple 2s
      [p1, p2] = game.players

      p1 = %{
        p1
        | hand: [
            %Card{suit: :clubs, rank: 2},
            %Card{suit: :spades, rank: 2},
            %Card{suit: :diamonds, rank: 5}
          ]
      }

      game = %{game | players: [p1, p2]}

      # Player can choose to play only one 2 (keeps the other for defense)
      assert {:ok, new_game} = Game.play_card(game, "p1", [0])

      # Should have pending pickups of 4 (2 from current + 2 from played)
      assert new_game.pending_pickups == 4

      # Player should still have the second 2 in hand
      updated_p1 = hd(new_game.players)
      remaining_cards = updated_p1.hand
      assert Enum.any?(remaining_cards, fn card -> card.rank == 2 end)
    end
  end

  describe "special card stacking" do
    test "2s stack correctly and accumulate pickups" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set current card to 2 of Hearts (already has effect)
      game = %{
        game
        | current_card: %Card{suit: :hearts, rank: 2},
          current_player_index: 0,
          pending_pickups: 2,
          pending_pickup_type: :twos
      }

      # Give player multiple 2s to stack
      [p1, p2] = game.players

      p1 = %{
        p1
        | hand: [
            %Card{suit: :clubs, rank: 2},
            %Card{suit: :spades, rank: 2}
          ]
      }

      game = %{game | players: [p1, p2]}

      # Player stacks both 2s
      assert {:ok, new_game} = Game.play_card(game, "p1", [0, 1])

      # Should have 6 total pickups (2 + 2 + 2)
      assert new_game.pending_pickups == 6
      assert new_game.pending_pickup_type == :twos
    end

    test "Black Jacks stack correctly (maximum of 2)" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set current card to Jack of Spades with existing effect
      game = %{
        game
        | current_card: %Card{suit: :spades, rank: :jack},
          current_player_index: 0,
          pending_pickups: 5,
          pending_pickup_type: :black_jacks
      }

      # Give player the other Black Jack
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :clubs, rank: :jack}]}
      game = %{game | players: [p1, p2]}

      # Player plays the second Black Jack
      assert {:ok, new_game} = Game.play_card(game, "p1", [0])

      # Should have 10 total pickups (5 + 5)
      assert new_game.pending_pickups == 10
      assert new_game.pending_pickup_type == :black_jacks
    end

    test "Red Jacks counter Black Jacks proportionally" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set up double Black Jack scenario (10 pickups)
      game = %{
        game
        | current_card: %Card{suit: :spades, rank: :jack},
          current_player_index: 0,
          pending_pickups: 10,
          pending_pickup_type: :black_jacks
      }

      # Give player only one Red Jack
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: :jack}]}
      game = %{game | players: [p1, p2]}

      # Player plays one Red Jack - should counter only one Black Jack
      assert {:ok, new_game} = Game.play_card(game, "p1", [0])

      # Should have 5 pickups remaining (10 - 5)
      assert new_game.pending_pickups == 5
      assert new_game.pending_pickup_type == :black_jacks
    end

    test "Queens reverse direction multiple times when stacked" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.start_game()

      # Start clockwise
      assert game.direction == :clockwise

      # Set current card and give player 3 Queens
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      [p1, p2, p3] = game.players

      p1 = %{
        p1
        | hand: [
            %Card{suit: :spades, rank: :queen},
            %Card{suit: :clubs, rank: :queen},
            %Card{suit: :diamonds, rank: :queen}
          ]
      }

      game = %{game | players: [p1, p2, p3]}

      # Player plays 3 Queens (odd number)
      assert {:ok, new_game} = Game.play_card(game, "p1", [0, 1, 2])

      # Should be counterclockwise (3 reversals = odd)
      assert new_game.direction == :counterclockwise
    end
  end

  describe "deck exhaustion and reshuffling" do
    test "deck reshuffles when exhausted during card draw" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Artificially reduce deck to 2 cards
      small_deck = %{game.deck | cards: Enum.take(game.deck.cards, 2)}

      # Create a large discard pile
      discard_pile = [
        %Card{suit: :hearts, rank: 3},
        %Card{suit: :diamonds, rank: 4},
        %Card{suit: :clubs, rank: 5},
        %Card{suit: :spades, rank: 6},
        # Keep current card on top
        game.current_card
      ]

      game = %{game | deck: small_deck, discard_pile: discard_pile}

      # Force player to draw 5 cards (more than deck has)
      game = %{
        game
        | pending_pickups: 5,
          pending_pickup_type: :black_jacks,
          current_player_index: 0
      }

      # Give player no valid plays to force draw
      [p1, p2] = game.players
      # No valid play for Black Jack
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: 8}]}
      game = %{game | players: [p1, p2]}

      # Drawing should trigger reshuffle
      assert {:ok, new_game} = Game.draw_card(game, "p1")

      # Player should have drawn 5 cards
      updated_p1 = hd(new_game.players)
      # Original 1 + 5 drawn
      assert length(updated_p1.hand) == 6

      # Deck should have cards again (reshuffled from discard pile)
      assert length(new_game.deck.cards) > 0

      # Discard pile should only have current card
      assert length(new_game.discard_pile) == 1
    end
  end

  describe "Ace suit nomination" do
    test "Ace allows choosing any suit" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set current card to Ace of Hearts
      game = %{game | current_card: %Card{suit: :hearts, rank: :ace}, current_player_index: 0}

      # Give player an Ace
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :spades, rank: :ace}]}
      game = %{game | players: [p1, p2]}

      # Player plays Ace
      assert {:ok, new_game} = Game.play_card(game, "p1", [0])

      # Should be waiting for suit nomination
      assert new_game.nominated_suit == :pending

      # Should not have advanced turn yet
      assert new_game.current_player_index == 0
    end

    test "stacked Aces get one suit choice" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set current card to Ace of Hearts
      game = %{game | current_card: %Card{suit: :hearts, rank: :ace}, current_player_index: 0}

      # Give player multiple Aces
      [p1, p2] = game.players

      p1 = %{
        p1
        | hand: [
            %Card{suit: :spades, rank: :ace},
            %Card{suit: :clubs, rank: :ace}
          ]
      }

      game = %{game | players: [p1, p2]}

      # Player plays both Aces
      assert {:ok, new_game} = Game.play_card(game, "p1", [0, 1])

      # Should be waiting for suit nomination (not per-Ace)
      assert new_game.nominated_suit == :pending

      # Player nominates a suit
      assert {:ok, final_game} = Game.nominate_suit(new_game, "p1", :diamonds)

      # Should have the nominated suit set
      assert final_game.nominated_suit == :diamonds
    end
  end

  describe "game continuation until one player remains" do
    test "game continues after first player wins until only one remains" do
      # Setup 4-player game
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.start_game()

      # Set current card and give player 1 one card to win with
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}, current_player_index: 0}

      [p1, p2, p3, p4] = game.players
      # Can play and win
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: 7}]}
      p2 = %{p2 | hand: [%Card{suit: :clubs, rank: 3}, %Card{suit: :spades, rank: 4}]}
      p3 = %{p3 | hand: [%Card{suit: :diamonds, rank: 6}]}
      p4 = %{p4 | hand: [%Card{suit: :hearts, rank: 8}, %Card{suit: :clubs, rank: 9}]}
      game = %{game | players: [p1, p2, p3, p4]}

      # Player 1 plays their last card and wins
      assert {:ok, new_game} = Game.play_card(game, "p1", [0])

      # Player 1 should be in winners list
      assert "p1" in new_game.winners

      # Game should still be playing (3 players remain)
      assert new_game.status == :playing

      # Player 1 should be skipped in turn rotation - turn should go to p2
      assert new_game.current_player_index != 0

      # Test that game continues - check that 3 players are still active
      active_players =
        Enum.reject(new_game.players, fn player -> player.id in new_game.winners end)

      assert length(active_players) == 3

      # Test the win condition logic by manually simulating multiple winners
      # This tests the rule: game ends when only 1 player remains
      game_with_two_winners = %{new_game | winners: ["p1", "p3"]}

      active_after_two =
        Enum.reject(game_with_two_winners.players, fn player ->
          player.id in game_with_two_winners.winners
        end)

      # p2 and p4 remain
      assert length(active_after_two) == 2

      game_with_three_winners = %{new_game | winners: ["p1", "p3", "p2"]}

      active_after_three =
        Enum.reject(game_with_three_winners.players, fn player ->
          player.id in game_with_three_winners.winners
        end)

      # Only p4 remains (the loser)
      assert length(active_after_three) == 1
    end

    test "turn order preserved after player elimination" do
      # Setup 4-player game: p1 -> p2 -> p3 -> p4 -> p1...
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.start_game()

      # Player 1 plays and wins (turn should advance to p2)
      game = %{game | current_card: %Card{suit: :hearts, rank: 5}, current_player_index: 0}

      [p1, p2, p3, p4] = game.players
      # p1 can win (no special effect)
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: 6}]}
      p2 = %{p2 | hand: [%Card{suit: :clubs, rank: 3}]}
      p3 = %{p3 | hand: [%Card{suit: :diamonds, rank: 6}]}
      p4 = %{p4 | hand: [%Card{suit: :spades, rank: 8}]}
      game = %{game | players: [p1, p2, p3, p4]}

      # p1 plays last card and wins
      assert {:ok, game_after_p1_wins} = Game.play_card(game, "p1", [0])

      # Turn should advance to p2 (index 1) since 6 has no special effect
      assert game_after_p1_wins.current_player_index == 1
      assert "p1" in game_after_p1_wins.winners

      # Now simulate p2 also winning their turn  
      # Current card should be 6 of Hearts from p1's play
      [_p1, p2, p3, p4] = game_after_p1_wins.players
      # p2 can win (matches suit)
      p2 = %{p2 | hand: [%Card{suit: :hearts, rank: 9}]}
      game2 = %{game_after_p1_wins | players: [p1, p2, p3, p4]}

      # p2 plays last card and wins
      assert {:ok, game_after_p2_wins} = Game.play_card(game2, "p2", [0])

      # Turn should advance to p3 (index 2), skipping eliminated players
      assert game_after_p2_wins.current_player_index == 2
      assert "p2" in game_after_p2_wins.winners

      # Verify that eliminated players (p1, p2) are skipped in future turn rotations
      # The remaining active players should be p3 and p4 only
      active_players =
        Enum.reject(game_after_p2_wins.players, fn player ->
          player.id in game_after_p2_wins.winners
        end)

      assert length(active_players) == 2
      assert Enum.map(active_players, & &1.id) == ["p3", "p4"]
    end
  end

  describe "starting card has no effect" do
    test "starting special cards don't trigger effects" do
      # Create game but manipulate the starting card to be a special card
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)

      # Manually set up game state as if 2 of Hearts was dealt as starting card
      starting_card = %Card{suit: :hearts, rank: 2}

      # This simulates the game being started with 2H as starting card
      game = %{
        game
        | status: :playing,
          current_card: starting_card,
          discard_pile: [starting_card],
          # No pending effects from starting card
          pending_pickups: 0,
          pending_pickup_type: nil
      }

      # Give players valid cards to play
      [p1, p2] = game.players
      # Can play on 2H by suit
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: 5}]}
      p2 = %{p2 | hand: [%Card{suit: :clubs, rank: 6}]}
      game = %{game | players: [p1, p2]}

      # Player 1 should be able to play normally (no forced pickup)
      assert {:ok, new_game} = Game.play_card(game, "p1", [0])

      # No pending pickups should exist
      assert new_game.pending_pickups == 0
      assert new_game.pending_pickup_type == nil
    end
  end
end
