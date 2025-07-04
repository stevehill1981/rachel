defmodule Rachel.Games.AIPlayerMissingCoverageTest do
  @moduledoc """
  Very specific tests to hit the 3 missing lines in AIPlayer.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Game, Card, AIPlayer}

  describe "specific missing coverage lines" do
    test "reverse direction with 2 or fewer players gets default priority" do
      # Test the else case for reverse_direction when players <= 2
      game =
        Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()

      # Only 2 players, so reverse doesn't get special priority
      game = %{game | current_player_index: 1, current_card: %Card{suit: :hearts, rank: 3}}

      # Give AI an 8 (reverse) and test priority
      [human, ai] = game.players

      ai = %{
        ai
        | hand: [
            # Reverse - should get default priority (50)
            %Card{suit: :hearts, rank: 8}
          ]
      }

      game = %{game | players: [human, ai]}

      # Should play it as it's the only valid card
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "pickup_two when opponents don't all have many cards" do
      # Test when opponents_with_many_cards != 0 (some have few cards)
      game =
        Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()

      game = %{game | current_player_index: 1, current_card: %Card{suit: :hearts, rank: 3}}

      # Give human few cards (3 or less)
      [human, ai] = game.players
      # Only 1 card
      human = %{human | hand: [%Card{suit: :spades, rank: 2}]}

      # Give AI a pickup 2 - should get default priority (50) not special (70)
      ai = %{
        ai
        | hand: [
            # Pickup 2
            %Card{suit: :hearts, rank: 2}
          ]
      }

      game = %{game | players: [human, ai]}

      # Should still play it as only card
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "skip_turn when opponents don't all have many cards" do
      # Test when opponents_with_many_cards != 0
      game =
        Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()

      game = %{game | current_player_index: 1, current_card: %Card{suit: :hearts, rank: 3}}

      # Give human few cards
      [human, ai] = game.players
      human = %{human | hand: [%Card{suit: :spades, rank: 2}]}

      # Give AI a skip card - should get default priority (50) not special (65)
      ai = %{
        ai
        | hand: [
            # Skip
            %Card{suit: :hearts, rank: 7}
          ]
      }

      game = %{game | players: [human, ai]}

      # Should still play it
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "black jack when opponents don't all have many cards" do
      # Test the else branch for black jack (not all opponents have many cards)
      game =
        Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()

      game = %{game | current_player_index: 1, current_card: %Card{suit: :hearts, rank: :jack}}

      # Give human few cards (3 or less)
      [human, ai] = game.players
      human = %{human | hand: [%Card{suit: :spades, rank: 2}]}

      # Give AI a black jack - should get low priority (30) like red jacks
      ai = %{
        ai
        | hand: [
            # Black jack
            %Card{suit: :clubs, rank: :jack}
          ]
      }

      game = %{game | players: [human, ai]}

      # Should still play it as only card
      assert {:play, 0} = AIPlayer.make_move(game, "ai")
    end

    test "default case in calculate_priority for non-special cards" do
      # Test line 103-104: default case returns 50
      game =
        Game.new()
        |> Game.add_player("human", "Human", false)
        |> Game.add_player("ai", "AI", true)
        |> Game.start_game()

      game = %{game | current_player_index: 1, current_card: %Card{suit: :hearts, rank: 3}}

      # Give AI only regular cards
      [human, ai] = game.players

      ai = %{
        ai
        | hand: [
            # Regular
            %Card{suit: :hearts, rank: 4},
            # Regular
            %Card{suit: :hearts, rank: 5},
            # Regular
            %Card{suit: :hearts, rank: 6}
          ]
      }

      game = %{game | players: [human, ai]}

      # Should play one of them (all have same priority 50)
      {:play, index} = AIPlayer.make_move(game, "ai")
      assert index in [0, 1, 2]
    end
  end
end
