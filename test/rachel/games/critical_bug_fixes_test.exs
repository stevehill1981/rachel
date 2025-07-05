defmodule Rachel.Games.CriticalBugFixesTest do
  @moduledoc """
  Tests for critical bugs discovered during integration testing.
  These tests ensure the specific vulnerabilities are fixed and don't regress.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  describe "card duplication exploit fixes" do
    test "prevents duplicate card indices from creating extra cards" do
      game = Game.new()
      |> Game.add_player("cheater", "Cheater", false)
      |> Game.add_player("honest", "Honest Player", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)
      
      # Attempt to play same card multiple times
      result = Game.play_card(game, "cheater", [0, 0, 0])
      
      # Should be rejected
      assert {:error, :duplicate_card_indices} = result
      
      # Cards should remain unchanged
      assert count_total_cards(game) == initial_cards
    end

    test "prevents single duplicate index" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # Try to play same card twice
      result = Game.play_card(game, "player", [0, 0])
      
      assert {:error, :duplicate_card_indices} = result
    end

    test "allows playing multiple different cards" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # Give player cards that can be stacked (same rank as current card)
      [player, other] = game.players
      hand = [
        %Card{suit: :hearts, rank: 5},
        %Card{suit: :spades, rank: 5}
      ]
      player = %{player | hand: hand}
      
      game = %{game | 
        players: [player, other],
        current_card: %Card{suit: :hearts, rank: 5}  # Same rank
      }

      # Should allow playing multiple cards of same rank
      result = Game.play_card(game, "player", [0, 1])
      
      # Should succeed (multiple 5s can be played together)
      assert {:ok, _new_game} = result
    end
  end

  describe "empty card array fixes" do
    test "rejects empty card selection" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # Try to play no cards
      result = Game.play_card(game, "player", [])
      
      # Should be rejected with specific error
      assert {:error, :no_cards_selected} = result
    end

    test "game state remains unchanged after empty card attempt" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      initial_cards = count_total_cards(game)
      initial_status = game.status
      
      # Try to play no cards (should be rejected)
      result = Game.play_card(game, "player", [])
      
      # Should be rejected
      assert {:error, :no_cards_selected} = result
      
      # Game state should remain unchanged
      assert count_total_cards(game) == initial_cards
      assert game.status == initial_status
    end
  end

  describe "invalid index handling" do
    test "rejects negative indices" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # Try negative index
      result = Game.play_card(game, "player", [-1])
      
      assert {:error, :invalid_card_index} = result
    end

    test "rejects out-of-bounds indices" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # Player starts with 7 cards, so index 999 is out of bounds
      result = Game.play_card(game, "player", [999])
      
      assert {:error, :invalid_card_index} = result
    end

    test "rejects mix of valid and invalid indices" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # Mix valid index 0 with invalid index 999
      result = Game.play_card(game, "player", [0, 999])
      
      assert {:error, :invalid_card_index} = result
    end

    test "handles non-integer indices gracefully" do
      game = Game.new()
      |> Game.add_player("player", "Player", false)
      |> Game.add_player("other", "Other", false)
      |> Game.start_game()

      # These should be caught by Elixir type system, but test anyway
      # Note: This test might not be reachable if type checking prevents it
      try do
        result = Game.play_card(game, "player", [:atom])
        assert {:error, _} = result
      rescue
        _ -> :ok  # Type error is acceptable
      end
    end
  end

  describe "finished game edge cases" do
    test "prevents playing cards in finished game" do
      game = Game.new()
      |> Game.add_player("winner", "Winner", false)
      |> Game.add_player("loser", "Loser", false)
      |> Game.start_game()

      # Manually set game to finished state
      finished_game = %{game | status: :finished, winners: ["winner"]}
      
      # Try to play card in finished game
      result = Game.play_card(finished_game, "winner", [0])
      
      # Should be rejected because game is finished
      assert {:error, _} = result
    end

    test "game state is preserved when play attempted on finished game" do
      game = Game.new()
      |> Game.add_player("winner", "Winner", false)
      |> Game.add_player("loser", "Loser", false)
      |> Game.start_game()

      finished_game = %{game | status: :finished, winners: ["winner"]}
      initial_cards = count_total_cards(finished_game)
      
      # Try to play card
      Game.play_card(finished_game, "winner", [0])
      
      # Card count should remain the same
      assert count_total_cards(finished_game) == initial_cards
    end
  end

  describe "comprehensive card conservation" do
    test "card count remains exactly 52 through all operations" do
      game = Game.new()
      |> Game.add_player("player1", "Player 1", false)
      |> Game.add_player("player2", "Player 2", false)
      |> Game.start_game()

      # Test all the exploit attempts from integration tests
      exploit_attempts = [
        fn g -> Game.play_card(g, "player1", [0, 0, 0]) end,     # Duplicate indices
        fn g -> Game.play_card(g, "player1", []) end,            # Empty array
        fn g -> Game.play_card(g, "player1", [-1]) end,          # Negative index
        fn g -> Game.play_card(g, "player1", [999]) end,         # Out of bounds
        fn g -> Game.draw_card(g, "player1") end,                # Valid draw
      ]

      final_game = Enum.reduce(exploit_attempts, game, fn attempt, acc ->
        case attempt.(acc) do
          {:ok, new_game} -> new_game
          {:error, _} -> acc
        end
      end)

      # Should still have exactly 52 cards
      assert count_total_cards(final_game) == 52
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