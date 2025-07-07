defmodule Rachel.Games.GameTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Deck, Game}

  describe "play_card/3" do
    setup do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      {:ok, game: game}
    end

    test "allows playing a single card matching suit", %{game: game} do
      # Set up game state with QH as current card
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      # Give player a 9H
      player = hd(game.players)
      player = %{player | hand: [%Card{suit: :hearts, rank: 9}]}
      game = %{game | players: [player | tl(game.players)]}

      # Should be able to play 9H on QH (matching suit)
      assert {:ok, _new_game} = Game.play_card(game, "p1", [0])
    end

    test "allows playing multiple cards - first matches suit, rest match rank", %{game: game} do
      # Set up game state with QH as current card
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      # Give player 9H and 9D
      player = hd(game.players)

      player = %{
        player
        | hand: [
            %Card{suit: :hearts, rank: 9},
            %Card{suit: :diamonds, rank: 9}
          ]
      }

      game = %{game | players: [player | tl(game.players)]}

      # Should be able to play 9H, 9D on QH
      # 9H matches suit with QH, 9D matches rank with 9H
      assert {:ok, _new_game} = Game.play_card(game, "p1", [0, 1])
    end

    test "allows playing multiple cards - first matches rank, rest match rank", %{game: game} do
      # Set up game state with QH as current card
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      # Give player QD and QS
      player = hd(game.players)

      player = %{
        player
        | hand: [
            %Card{suit: :diamonds, rank: :queen},
            %Card{suit: :spades, rank: :queen}
          ]
      }

      game = %{game | players: [player | tl(game.players)]}

      # Should be able to play QD, QS on QH
      # QD matches rank with QH, QS matches rank with QD
      assert {:ok, _new_game} = Game.play_card(game, "p1", [0, 1])
    end

    test "rejects playing cards that don't match", %{game: game} do
      # Set up game state with QH as current card
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      # Give player a 9S (doesn't match suit or rank)
      player = hd(game.players)
      player = %{player | hand: [%Card{suit: :spades, rank: 9}]}
      game = %{game | players: [player | tl(game.players)]}

      # Should not be able to play 9S on QH
      assert {:error, :first_card_invalid} = Game.play_card(game, "p1", [0])
    end

    test "rejects stacking cards with different ranks", %{game: game} do
      # Set up game state with QH as current card
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      # Give player 9H and 10H (different ranks)
      player = hd(game.players)

      player = %{
        player
        | hand: [
            %Card{suit: :hearts, rank: 9},
            %Card{suit: :hearts, rank: 10}
          ]
      }

      game = %{game | players: [player | tl(game.players)]}

      # Should not be able to play cards with different ranks together
      assert {:error, :can_only_stack_same_rank} = Game.play_card(game, "p1", [0, 1])
    end

    test "cards are properly managed in deck and discard pile", %{game: game} do
      # Start the game to deal initial hands
      game = Game.start_game(game)

      # Count initial cards: players get 7 cards each (2 players = 14), 1 current card, 51-14 = 37 in deck
      total_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
      total_in_deck = Deck.size(game.deck)
      total_in_discard = length(game.discard_pile)
      # Don't double-count current card if it's already in discard pile
      current_card_count =
        if game.current_card && game.current_card not in game.discard_pile, do: 1, else: 0

      total_cards = total_in_hands + total_in_deck + total_in_discard + current_card_count

      # Should always have 52 cards total
      assert total_cards == 52

      # Play a card and verify counts still add up
      if total_in_hands > 0 do
        [first_player | _] = game.players

        if length(first_player.hand) > 0 do
          case Game.play_card(game, first_player.id, [0]) do
            {:ok, new_game} ->
              new_total_in_hands =
                Enum.sum(Enum.map(new_game.players, fn p -> length(p.hand) end))

              new_total_in_deck = Deck.size(new_game.deck)
              new_total_in_discard = length(new_game.discard_pile)
              # Don't double-count current card if it's already in discard pile
              new_current_card_count =
                if new_game.current_card && new_game.current_card not in new_game.discard_pile,
                  do: 1,
                  else: 0

              new_total_cards =
                new_total_in_hands + new_total_in_deck + new_total_in_discard +
                  new_current_card_count

              # Should still have 52 cards total
              assert new_total_cards == 52

            _ ->
              # If play fails, that's fine for this test
              :ok
          end
        end
      end
    end

    test "allows same rank cards - Queen on Queen", %{game: game} do
      # Set up game state with QH as current card
      game = %{game | current_card: %Card{suit: :hearts, rank: :queen}, current_player_index: 0}

      # Give player a QS (same rank, different suit)
      player = hd(game.players)
      player = %{player | hand: [%Card{suit: :spades, rank: :queen}]}
      game = %{game | players: [player | tl(game.players)]}

      # Should be able to play QS on QH (matching rank)
      assert {:ok, _new_game} = Game.play_card(game, "p1", [0])
    end

    test "blocks Queen on Queen when there are pending pickups", %{game: game} do
      # Set up game state with QH as current card and pending 2s
      game = %{
        game
        | current_card: %Card{suit: :hearts, rank: :queen},
          current_player_index: 0,
          pending_pickups: 2,
          pending_pickup_type: :twos
      }

      # Give player a QS
      player = hd(game.players)
      player = %{player | hand: [%Card{suit: :spades, rank: :queen}]}
      game = %{game | players: [player | tl(game.players)]}

      # Should NOT be able to play QS when 2s are pending
      assert {:error, :must_play_twos} = Game.play_card(game, "p1", [0])
    end

    test "game ends when only one player remains" do
      # Create a 3-player game
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.start_game()

      # Set up a game state where p1 and p2 have empty hands (already won), p3 has cards
      game = %{
        game
        | current_card: %Card{suit: :hearts, rank: :king},
          # Start with p3's turn
          current_player_index: 2,
          # p1 and p2 already won
          winners: ["p1", "p2"]
      }

      [p1, p2, p3] = game.players
      # Already won
      p1 = %{p1 | hand: []}
      # Already won
      p2 = %{p2 | hand: []}
      # Last remaining player - will be loser
      p3 = %{p3 | hand: [%Card{suit: :hearts, rank: :queen}]}
      game = %{game | players: [p1, p2, p3]}

      # p3 plays their last card and "wins", but this should trigger game end
      assert {:ok, game} = Game.play_card(game, "p3", [0])
      assert "p3" in game.winners
      # Game should end immediately - only p3 remained active
      assert game.status == :finished

      # Should have 3 winners total (everyone finished)
      assert length(game.winners) == 3
      assert "p1" in game.winners
      assert "p2" in game.winners
      assert "p3" in game.winners
    end
  end

  describe "critical bug fixes" do
    test "deck recycling works correctly - cards are not permanently lost" do
      # Create a minimal deck with only a few cards to force recycling
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)

      # Create a tiny deck with only 3 cards for testing
      tiny_deck = %Deck{
        cards: [
          %Card{suit: :hearts, rank: 2},
          %Card{suit: :spades, rank: 2},
          %Card{suit: :clubs, rank: 3}
        ]
      }

      current_card = %Card{suit: :hearts, rank: 4}

      # Set up game with minimal deck
      game = %{
        game
        | deck: tiny_deck,
          current_card: current_card,
          # Should include current card in discard pile
          discard_pile: [current_card],
          current_player_index: 0,
          status: :playing
      }

      # Give players cards from outside the deck
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :diamonds, rank: 5}]}
      p2 = %{p2 | hand: [%Card{suit: :diamonds, rank: 6}]}
      game = %{game | players: [p1, p2]}

      # Force drawing more cards than are in the deck to trigger recycling
      player = hd(game.players)

      # This should trigger deck recycling without losing cards
      {:ok, game_after_draw} = Game.draw_card(game, "p1")

      # After recycling, we should have cards available
      # The discard pile should have been reshuffled (except current card)
      # and the player should have received cards
      player_after = hd(game_after_draw.players)

      # Player should have received at least 1 card
      assert length(player_after.hand) > length(player.hand)

      # Current card should remain the same (not recycled)
      assert game_after_draw.current_card == current_card

      # Discard pile should only contain the current card after recycling
      assert game_after_draw.discard_pile == [current_card]
    end

    test "stacking detection works correctly for 2s" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set up game with a 2 as current card to enable stacking
      game = %{
        game
        | current_card: %Card{suit: :hearts, rank: 2},
          pending_pickups: 2,
          pending_pickup_type: :twos,
          current_player_index: 0
      }

      # Give player 1 a 2 to stack
      [p1, p2] = game.players

      p1 = %{
        p1
        | hand: [
            # Should be playable for stacking
            %Card{suit: :spades, rank: 2},
            # Should NOT be playable during stacking
            %Card{suit: :clubs, rank: 5}
          ]
      }

      game = %{game | players: [p1, p2]}

      # Test that get_valid_plays correctly identifies the 2 as playable
      valid_plays = Game.get_valid_plays(game, p1)

      # Should have exactly 1 valid play (the 2 of spades)
      assert length(valid_plays) == 1
      {valid_card, _index} = hd(valid_plays)
      assert valid_card.rank == 2
      assert valid_card.suit == :spades

      # Test that has_valid_play? returns true
      assert Game.has_valid_play?(game, p1) == true

      # Test that the 2 can actually be played
      assert {:ok, _new_game} = Game.play_card(game, "p1", [0])
    end

    test "stacking detection works correctly for black jacks" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set up game with black jack pending pickups
      game = %{
        game
        | current_card: %Card{suit: :spades, rank: :jack},
          pending_pickups: 5,
          pending_pickup_type: :black_jacks,
          current_player_index: 0
      }

      # Give player 1 a jack to counter and a red jack
      [p1, p2] = game.players

      p1 = %{
        p1
        | hand: [
            # Black jack - should be playable for stacking
            %Card{suit: :clubs, rank: :jack},
            # Red jack - should be playable for countering
            %Card{suit: :hearts, rank: :jack},
            # Should NOT be playable during black jack stacking
            %Card{suit: :clubs, rank: 5}
          ]
      }

      game = %{game | players: [p1, p2]}

      # Test that get_valid_plays correctly identifies both jacks as playable
      valid_plays = Game.get_valid_plays(game, p1)

      # Should have exactly 2 valid plays (both jacks)
      assert length(valid_plays) == 2

      # Both should be jacks
      jack_plays = Enum.filter(valid_plays, fn {card, _index} -> card.rank == :jack end)
      assert length(jack_plays) == 2

      # Test that has_valid_play? returns true
      assert Game.has_valid_play?(game, p1) == true
    end

    test "player with no stacking cards is forced to draw during stacking" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      # Set up game with 2s stacking in progress
      game = %{
        game
        | current_card: %Card{suit: :hearts, rank: 2},
          # Two 2s played already
          pending_pickups: 4,
          pending_pickup_type: :twos,
          current_player_index: 0
      }

      # Give player 1 NO 2s - they should be forced to draw
      [p1, p2] = game.players

      p1 = %{
        p1
        | hand: [
            %Card{suit: :clubs, rank: 5},
            %Card{suit: :spades, rank: :king},
            %Card{suit: :hearts, rank: 9}
          ]
      }

      game = %{game | players: [p1, p2]}

      # Test that player has NO valid plays
      valid_plays = Game.get_valid_plays(game, p1)
      assert length(valid_plays) == 0
      assert Game.has_valid_play?(game, p1) == false

      # Test that draw_card works and picks up the correct number
      assert {:ok, game_after_draw} = Game.draw_card(game, "p1")

      # Player should have drawn 4 cards (the pending pickups)
      player_after = hd(game_after_draw.players)
      assert length(player_after.hand) == length(p1.hand) + 4

      # Pending pickups should be cleared
      assert game_after_draw.pending_pickups == 0
      assert game_after_draw.pending_pickup_type == nil
    end
  end

  describe "card dealing rules" do
    test "deals 7 cards for 6 or fewer players" do
      # Test with 2 players
      game_2p =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.start_game()

      assert length(hd(game_2p.players).hand) == 7
      assert length(hd(tl(game_2p.players)).hand) == 7

      # Test with 6 players
      game_6p =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.add_player("p5", "Player 5", false)
        |> Game.add_player("p6", "Player 6", false)
        |> Game.start_game()

      Enum.each(game_6p.players, fn player ->
        assert length(player.hand) == 7
      end)
    end

    test "deals 5 cards for 7-8 players" do
      # Test with 7 players
      game_7p =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.add_player("p5", "Player 5", false)
        |> Game.add_player("p6", "Player 6", false)
        |> Game.add_player("p7", "Player 7", false)
        |> Game.start_game()

      Enum.each(game_7p.players, fn player ->
        assert length(player.hand) == 5
      end)

      # Test with 8 players
      game_8p =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.add_player("p5", "Player 5", false)
        |> Game.add_player("p6", "Player 6", false)
        |> Game.add_player("p7", "Player 7", false)
        |> Game.add_player("p8", "Player 8", false)
        |> Game.start_game()

      Enum.each(game_8p.players, fn player ->
        assert length(player.hand) == 5
      end)
    end

    test "leaves healthy deck size for 8 players" do
      game =
        Game.new()
        |> Game.add_player("p1", "Player 1", false)
        |> Game.add_player("p2", "Player 2", false)
        |> Game.add_player("p3", "Player 3", false)
        |> Game.add_player("p4", "Player 4", false)
        |> Game.add_player("p5", "Player 5", false)
        |> Game.add_player("p6", "Player 6", false)
        |> Game.add_player("p7", "Player 7", false)
        |> Game.add_player("p8", "Player 8", false)
        |> Game.start_game()

      # 52 cards - 40 dealt (8×5) - 1 starting card = 11 cards remaining
      # Healthy enough for Black Jack stacks (max 10 cards pickup)
      remaining_cards = length(game.deck.cards)
      assert remaining_cards == 11
    end
  end
end
