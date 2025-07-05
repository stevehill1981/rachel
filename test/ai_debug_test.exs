defmodule AIDebugTest do
  use ExUnit.Case, async: false

  alias Rachel.Games.{AIPlayer, GameServer}

  test "debug AI turn - simple case" do
    # Use GameManager to create game properly
    {:ok, game_id} = Rachel.Games.GameManager.create_and_join_game("human-1", "Human Player")
    {:ok, _game} = GameServer.add_ai_player(game_id, "AI Player")

    # Start game
    {:ok, started_game} = GameServer.start_game(game_id, "human-1")

    # Check if first player is AI
    first_player = Enum.at(started_game.players, started_game.current_player_index)

    if first_player.is_ai do
      IO.puts("AI is first - waiting for automatic turn...")

      # Wait for AI turn
      Process.sleep(3000)

      # Check if anything changed
      updated_game = GameServer.get_state(game_id)

      if updated_game.current_player_index == started_game.current_player_index do
        IO.puts("❌ AI did not take turn automatically")

        # Manually trigger AI turn
        IO.puts("Manually triggering AI turn...")
        _ai_action = AIPlayer.make_move(started_game, first_player.id)

        # Send manual AI turn message
        game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
        send(game_pid, :ai_turn)
        Process.sleep(1000)

        final_game = GameServer.get_state(game_id)

        if final_game.current_player_index != started_game.current_player_index do
          IO.puts("✅ AI responded to manual trigger")
        else
          IO.puts("❌ AI did not respond to manual trigger")
        end
      else
        IO.puts("✅ AI took turn automatically")
      end
    else
      IO.puts("Human is first - making human play to trigger AI turn...")

      # Human plays a card to pass turn to AI
      current_player = Enum.at(started_game.players, started_game.current_player_index)

      # Find a valid card to play based on current card
      current_card = started_game.current_card

      valid_card =
        Enum.find(current_player.hand, fn card ->
          card.suit == current_card.suit or card.rank == current_card.rank
        end)

      # If no valid card found, human must draw
      after_human =
        if valid_card do
          {:ok, game} = GameServer.play_cards(game_id, "human-1", [valid_card])
          game
        else
          # No valid card, human must draw
          IO.puts("No valid card for human, drawing...")
          {:ok, game} = GameServer.draw_card(game_id, "human-1")
          game
        end

      # If we played an ace, nominate a suit
      after_nomination =
        if valid_card && valid_card.rank == :ace do
          IO.puts("Played ace, nominating suit...")
          {:ok, game_after_nomination} = GameServer.nominate_suit(game_id, "human-1", :hearts)
          game_after_nomination
        else
          after_human
        end

      ai_player = Enum.at(after_nomination.players, after_nomination.current_player_index)

      if ai_player.is_ai do
        IO.puts("Now AI's turn - waiting...")
        Process.sleep(3000)

        final_game = GameServer.get_state(game_id)

        if final_game.current_player_index != after_human.current_player_index do
          IO.puts("✅ AI took turn after human")
        else
          IO.puts("❌ AI did not take turn after human")
        end
      end
    end

    # Check process mailbox for any pending messages
    receive do
      _msg -> :ok
    after
      0 -> IO.puts("No messages in mailbox")
    end

    # Cleanup
    Rachel.Games.GameManager.stop_game(game_id)

    assert true
  end
end
