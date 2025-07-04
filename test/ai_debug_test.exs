defmodule AIDebugTest do
  use ExUnit.Case, async: false

  alias Rachel.Games.{GameServer, AIPlayer}

  test "debug AI turn - simple case" do
    # Use GameManager to create game properly
    {:ok, game_id} = Rachel.Games.GameManager.create_and_join_game("human-1", "Human Player")
    {:ok, game} = GameServer.add_ai_player(game_id, "AI Player")

    IO.inspect(game.players, label: "Players before start")

    # Start game
    {:ok, started_game} = GameServer.start_game(game_id, "human-1")

    IO.inspect(started_game.current_player_index, label: "Current player index")

    IO.inspect(Enum.at(started_game.players, started_game.current_player_index),
      label: "Current player"
    )

    IO.inspect(started_game.current_card, label: "Current card on table")

    # Check if first player is AI
    first_player = Enum.at(started_game.players, started_game.current_player_index)

    if first_player.is_ai do
      IO.puts("AI is first - waiting for automatic turn...")

      # Wait for AI turn
      Process.sleep(3000)

      # Check if anything changed
      updated_game = GameServer.get_state(game_id)

      IO.inspect(updated_game.current_player_index, label: "Current player after wait")
      IO.inspect(updated_game.current_card, label: "Current card after wait")

      if updated_game.current_player_index == started_game.current_player_index do
        IO.puts("❌ AI did not take turn automatically")

        # Manually trigger AI turn
        IO.puts("Manually triggering AI turn...")
        ai_action = AIPlayer.make_move(started_game, first_player.id)
        IO.inspect(ai_action, label: "AI decision")

        # Send manual AI turn message
        game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
        send(game_pid, :ai_turn)
        Process.sleep(1000)

        final_game = GameServer.get_state(game_id)
        IO.inspect(final_game.current_player_index, label: "Current player after manual trigger")

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
      IO.inspect(current_card, label: "Current card on table")

      valid_card =
        Enum.find(current_player.hand, fn card ->
          card.suit == current_card.suit or card.rank == current_card.rank or card.rank == :ace
        end)

      card_to_play = valid_card || hd(current_player.hand)
      IO.inspect(card_to_play, label: "Card to play")

      {:ok, after_human} = GameServer.play_cards(game_id, "human-1", [card_to_play])

      # If we played an ace, nominate a suit
      if card_to_play.rank == :ace do
        IO.puts("Played ace, nominating suit...")
        {:ok, ^after_human} = GameServer.nominate_suit(game_id, "human-1", :hearts)
      end

      ai_player = Enum.at(after_human.players, after_human.current_player_index)
      IO.inspect(ai_player, label: "AI player after human turn")

      if ai_player.is_ai do
        IO.puts("Now AI's turn - waiting...")
        Process.sleep(3000)

        final_game = GameServer.get_state(game_id)
        IO.inspect(final_game.current_player_index, label: "Current player after AI should play")

        if final_game.current_player_index != after_human.current_player_index do
          IO.puts("✅ AI took turn after human")
        else
          IO.puts("❌ AI did not take turn after human")
        end
      end
    end

    # Check process mailbox for any pending messages
    receive do
      msg -> IO.inspect(msg, label: "Received message")
    after
      0 -> IO.puts("No messages in mailbox")
    end

    # Cleanup
    Rachel.Games.GameManager.stop_game(game_id)

    assert true
  end
end
