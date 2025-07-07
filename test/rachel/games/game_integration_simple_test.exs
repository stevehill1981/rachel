defmodule Rachel.Games.GameIntegrationSimpleTest do
  @moduledoc """
  Simplified integration tests focusing on the critical bugs we just fixed.
  These tests verify that real gameplay scenarios work end-to-end.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "deck recycling scenarios" do
    test "cards are preserved through deck recycling" do
      # Create a game that will force deck recycling
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      initial_total_cards = count_total_cards(game)
      assert initial_total_cards == 52

      # Force multiple card draws to eventually trigger recycling
      game = force_deck_recycling(game, 10)

      # Verify cards are still preserved
      final_total_cards = count_total_cards(game)

      assert final_total_cards == 52,
             "Cards lost during deck recycling: #{initial_total_cards} → #{final_total_cards}"

      # Verify game is still playable
      assert game.status == :playing
      assert game.current_card != nil
    end

    test "current card remains consistent through recycling" do
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      original_current_card = game.current_card

      # Force recycling
      game = force_deck_recycling(game, 5)

      # Current card should remain the same
      assert game.current_card == original_current_card
    end
  end

  describe "stacking scenarios" do
    test "2s stacking works correctly" do
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      # Set up a 2 as current card
      current_2 = %Card{suit: :hearts, rank: 2}
      game = %{game | current_card: current_2}

      # Give player1 a 2 to stack
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :spades, rank: 2}]}
      p2 = %{p2 | hand: [%Card{suit: :clubs, rank: 5}]}
      game = %{game | players: [p1, p2], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Player1 should be able to play the 2
      assert Game.has_valid_play?(game, p1) == true

      valid_plays = Game.get_valid_plays(game, p1)
      assert length(valid_plays) == 1
      {card, _index} = hd(valid_plays)
      assert card.rank == 2

      # Play the 2
      {:ok, game} = Game.play_card(game, "player1", [0])
      assert game.pending_pickups == 2
      assert game.pending_pickup_type == :twos

      # Cards should be preserved
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "black jack stacking works correctly" do
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      # Set up a black jack as current card
      current_jack = %Card{suit: :spades, rank: :jack}
      game = %{game | current_card: current_jack}

      # Give player1 another black jack
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :clubs, rank: :jack}]}
      p2 = %{p2 | hand: [%Card{suit: :hearts, rank: 5}]}
      game = %{game | players: [p1, p2], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Player1 should be able to play the black jack
      assert Game.has_valid_play?(game, p1) == true

      # Play the black jack
      {:ok, game} = Game.play_card(game, "player1", [0])
      assert game.pending_pickups == 5
      assert game.pending_pickup_type == :black_jacks

      # Cards should be preserved
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end

    test "red jack counters black jack correctly" do
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      # Set up pending black jack pickups
      current_jack = %Card{suit: :spades, rank: :jack}

      game = %{
        game
        | current_card: current_jack,
          pending_pickups: 5,
          pending_pickup_type: :black_jacks
      }

      # Give player1 a red jack to counter
      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: :hearts, rank: :jack}]}
      p2 = %{p2 | hand: [%Card{suit: :clubs, rank: 5}]}
      game = %{game | players: [p1, p2], current_player_index: 0}

      initial_cards = count_total_cards(game)

      # Player1 should be able to play the red jack
      assert Game.has_valid_play?(game, p1) == true

      # Play the red jack
      {:ok, game} = Game.play_card(game, "player1", [0])
      # Should cancel the black jack
      assert game.pending_pickups == 0
      assert game.pending_pickup_type == nil

      # Cards should be preserved
      final_cards = count_total_cards(game)
      assert final_cards == initial_cards
    end
  end

  describe "card conservation" do
    test "no cards lost during normal gameplay" do
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      initial_cards = count_total_cards(game)
      assert initial_cards == 52

      # Play several rounds of normal moves
      game = play_random_moves(game, 20)

      # Cards should be preserved
      final_cards = count_total_cards(game)
      assert final_cards == 52, "Lost #{initial_cards - final_cards} cards during gameplay"
    end

    test "no cards lost during special card effects" do
      game =
        Game.new()
        |> Game.add_player("player1", "Alice", false)
        |> Game.add_player("player2", "Bob", false)
        |> Game.start_game()

      initial_cards = count_total_cards(game)

      # Try to make some moves that might involve drawing
      game = play_random_moves(game, 5)

      # Cards should be preserved regardless of what happened
      final_cards = count_total_cards(game)

      assert final_cards == initial_cards,
             "Lost #{initial_cards - final_cards} cards during special effects"
    end
  end

  # Helper functions
  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)

    cards_in_hands + cards_in_deck + cards_in_discard
  end

  defp force_deck_recycling(game, draws_to_force) do
    Enum.reduce(1..draws_to_force, game, fn _i, acc_game ->
      current_player = Game.current_player(acc_game)

      case Game.draw_card(acc_game, current_player.id) do
        {:ok, new_game} ->
          advance_to_next_player(new_game)

        {:error, _} ->
          advance_to_next_player(acc_game)
      end
    end)
  end

  defp play_random_moves(game, max_moves) do
    Enum.reduce_while(1..max_moves, game, fn _i, acc_game ->
      if acc_game.status == :finished do
        {:halt, acc_game}
      else
        current_player = Game.current_player(acc_game)

        case try_make_move(acc_game, current_player.id) do
          {:ok, new_game} -> {:cont, new_game}
          {:error, _} -> {:halt, acc_game}
        end
      end
    end)
  end

  defp try_make_move(game, player_id) do
    player = Enum.find(game.players, fn p -> p.id == player_id end)

    if Game.has_valid_play?(game, player) do
      # Try to play first valid card
      valid_plays = Game.get_valid_plays(game, player)

      case valid_plays do
        [{_card, index} | _] -> Game.play_card(game, player_id, [index])
        [] -> Game.draw_card(game, player_id)
      end
    else
      # Try to draw
      Game.draw_card(game, player_id)
    end
  end

  defp advance_to_next_player(game) do
    current_index = game.current_player_index
    player_count = length(game.players)
    next_index = rem(current_index + 1, player_count)
    %{game | current_player_index: next_index}
  end
end
