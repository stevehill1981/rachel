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
      current_card_count = if game.current_card, do: 1, else: 0

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
              new_current_card_count = if new_game.current_card, do: 1, else: 0

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
end
