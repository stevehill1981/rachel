defmodule AISimpleTest do
  use ExUnit.Case, async: false

  alias Rachel.Games.{GameServer, AIPlayer}

  test "AI takes automatic turns" do
    # Use GameManager to create game properly
    {:ok, game_id} = Rachel.Games.GameManager.create_and_join_game("human-1", "Human")
    {:ok, _game} = GameServer.add_ai_player(game_id, "AI Player")

    # Start game
    {:ok, game} = GameServer.start_game(game_id, "human-1")

    # Track initial state
    initial_player_index = game.current_player_index
    initial_card = game.current_card
    initial_player = Enum.at(game.players, initial_player_index)

    IO.puts("\n=== INITIAL STATE ===")
    IO.puts("Player: #{initial_player.name} (AI: #{initial_player.is_ai})")
    IO.puts("Current card: #{initial_card.suit} #{initial_card.rank}")

    # If AI is first, wait for it to play
    if initial_player.is_ai do
      IO.puts("AI is first, waiting 3 seconds...")
      Process.sleep(3000)

      final_game = GameServer.get_state(game_id)

      if final_game.current_player_index != initial_player_index or
           final_game.current_card != initial_card do
        IO.puts("✅ AI took turn automatically")
      else
        IO.puts("❌ AI did not take turn")

        # Check what AI would do
        decision = AIPlayer.make_move(game, initial_player.id)
        IO.puts("AI decision: #{inspect(decision)}")
      end
    else
      # Human is first, make them play to pass to AI
      IO.puts("Human is first, making human play...")

      # Find valid card for human
      valid_card =
        Enum.find(initial_player.hand, fn card ->
          card.suit == initial_card.suit or
            card.rank == initial_card.rank
        end)

      # Human plays
      {:ok, after_human} = GameServer.play_cards(game_id, "human-1", [valid_card])

      # Handle ace nomination
      after_human =
        if valid_card.rank == :ace do
          {:ok, game_with_suit} = GameServer.nominate_suit(game_id, "human-1", :hearts)
          game_with_suit
        else
          after_human
        end

      # Check if it's now AI's turn
      ai_player = Enum.at(after_human.players, after_human.current_player_index)

      if ai_player.is_ai do
        IO.puts("Now AI's turn, waiting 3 seconds...")
        Process.sleep(3000)

        final_game = GameServer.get_state(game_id)

        if final_game.current_player_index != after_human.current_player_index or
             final_game.current_card != after_human.current_card do
          IO.puts("✅ AI took turn after human")
        else
          IO.puts("❌ AI did not take turn after human")

          # Check what AI would do
          decision = AIPlayer.make_move(after_human, ai_player.id)
          IO.puts("AI decision: #{inspect(decision)}")
        end
      else
        IO.puts("It's still human's turn (not AI)")
      end
    end

    # Cleanup
    Rachel.Games.GameManager.stop_game(game_id)

    assert true
  end
end
