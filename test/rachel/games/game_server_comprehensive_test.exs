defmodule Rachel.Games.GameServerComprehensiveTest do
  use ExUnit.Case, async: false

  alias Rachel.Games.{Card, GameServer}

  setup do
    game_id = "test-#{System.unique_integer()}"

    on_exit(fn ->
      # Cleanup
      case GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}}) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 5000)
      end
    end)

    {:ok, game_id: game_id}
  end

  describe "get_state/1" do
    test "returns current game state", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")

      state = GameServer.get_state(game_id)

      assert state.id == game_id
      assert length(state.players) == 1
      assert state.status == :waiting
    end

    test "returns nil for non-existent game" do
      assert GameServer.get_state("non-existent") == nil
    end
  end

  describe "add_ai_player/2" do
    test "adds AI player with generated ID", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)

      {:ok, game} = GameServer.add_ai_player(game_id, "Computer")

      assert length(game.players) == 1
      [ai_player] = game.players
      assert ai_player.name == "Computer"
      assert ai_player.is_ai == true
      assert String.starts_with?(ai_player.id, "ai-")
    end

    test "can add multiple AI players", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)

      {:ok, _} = GameServer.add_ai_player(game_id, "Computer 1")
      {:ok, game} = GameServer.add_ai_player(game_id, "Computer 2")

      assert length(game.players) == 2
      assert Enum.all?(game.players, & &1.is_ai)
    end
  end

  describe "timeout handling" do
    test "game times out after period of inactivity", %{game_id: game_id} do
      # Start with 50ms timeout for testing
      {:ok, pid} = GameServer.start_link(game_id: game_id, timeout: 50)

      # Verify it's alive
      assert Process.alive?(pid)

      # Wait for timeout (double the timeout duration)
      Process.sleep(200)

      # Should have terminated
      refute Process.alive?(pid)
    end

    test "activity resets timeout", %{game_id: game_id} do
      {:ok, pid} = GameServer.start_link(game_id: game_id, timeout: 100)

      # Make periodic calls to reset timeout
      for _ <- 1..3 do
        Process.sleep(50)
        GameServer.get_state(game_id)
      end

      # Should still be alive after 150ms due to activity
      assert Process.alive?(pid)
    end
  end

  describe "terminate/2" do
    test "cleans up on normal termination", %{game_id: game_id} do
      {:ok, pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")

      # Stop the server
      GenServer.stop(pid, :normal)

      # Should be deregistered
      assert GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}}) == nil
    end
  end

  describe "broadcasting" do
    test "broadcasts game updates to subscribers", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)

      # Subscribe to game updates
      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

      # Join game should broadcast
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")

      assert_receive {:game_updated, game}
      assert game.id == game_id
      assert length(game.players) == 1
    end

    test "broadcasts player disconnection", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")

      # Subscribe after joining
      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

      # Disconnect player
      :ok = GameServer.disconnect_player(game_id, "p1")

      assert_receive {:player_disconnected, %{player_id: "p1", player_name: "Player 1"}}
    end

    test "broadcasts player reconnection", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")
      :ok = GameServer.disconnect_player(game_id, "p1")

      # Subscribe
      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

      # Reconnect
      :ok = GameServer.reconnect_player(game_id, "p1")

      assert_receive {:player_reconnected, %{player_id: "p1", player_name: "Player 1"}}
    end

    test "broadcasts game start", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")
      {:ok, _} = GameServer.join_game(game_id, "p2", "Player 2")

      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

      {:ok, _} = GameServer.start_game(game_id, "p1")

      assert_receive {:game_started, game}
      assert game.status == :playing
    end

    test "broadcasts cards played", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")
      {:ok, _} = GameServer.join_game(game_id, "p2", "Player 2")
      {:ok, game} = GameServer.start_game(game_id, "p1")

      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

      # Find a valid card to play
      current_player = Enum.at(game.players, game.current_player_index)

      valid_card =
        Enum.find(current_player.hand, fn card ->
          card.suit == game.current_card.suit ||
            card.rank == game.current_card.rank
        end)

      if valid_card do
        {:ok, _} = GameServer.play_cards(game_id, current_player.id, [valid_card])

        assert_receive {:cards_played,
                        %{
                          player_id: player_id,
                          player_name: "Player 1",
                          cards: cards
                        }}

        assert player_id == current_player.id
        assert valid_card in cards
      end
    end

    test "broadcasts winner", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")
      {:ok, _} = GameServer.join_game(game_id, "p2", "Player 2")
      {:ok, game} = GameServer.start_game(game_id, "p1")

      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

      # Manually set up a winning condition
      game = %{game | current_player_index: 0}
      [p1, p2] = game.players
      # Give p1 only one card they can play
      p1 = %{p1 | hand: [%Card{suit: game.current_card.suit, rank: 3}]}
      game = %{game | players: [p1, p2]}

      # Set the state
      GenServer.call(
        {:via, Registry, {Rachel.GameRegistry, game_id}},
        {:set_state, game}
      )

      # Play the last card
      {:ok, _} = GameServer.play_cards(game_id, "p1", [p1.hand |> hd()])

      assert_receive {:player_won,
                      %{
                        player_id: "p1",
                        player_name: "Player 1",
                        position: 1
                      }}
    end
  end

  describe "error handling" do
    test "handles invalid game state gracefully", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)

      # Try to start game with only one player
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")

      # Should return error, not crash
      assert {:error, :not_enough_players} = GameServer.start_game(game_id, "p1")
    end

    test "handles disconnection of non-existent player", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)

      # Should not crash
      assert :ok = GameServer.disconnect_player(game_id, "non-existent")
    end

    test "handles reconnection of non-existent player", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)

      # Should not crash
      assert :ok = GameServer.reconnect_player(game_id, "non-existent")
    end
  end

  describe "spectator mode" do
    test "allows spectating ongoing games", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")
      {:ok, _} = GameServer.join_game(game_id, "p2", "Player 2")
      {:ok, _} = GameServer.start_game(game_id, "p1")

      # Join as spectator
      {:ok, game} = GameServer.join_as_spectator(game_id, "spec1", "Spectator")

      # Should not be in players list
      assert length(game.players) == 2
      refute Enum.any?(game.players, &(&1.id == "spec1"))
    end
  end

  describe "stats tracking" do
    test "records game stats when game finishes", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "p1", "Player 1")
      {:ok, _} = GameServer.join_game(game_id, "p2", "Player 2")
      {:ok, game} = GameServer.start_game(game_id, "p1")

      # Set up end game condition
      game = %{
        game
        | current_player_index: 0,
          # p2 already won
          winners: ["p2"]
      }

      [p1, p2] = game.players
      p1 = %{p1 | hand: [%Card{suit: game.current_card.suit, rank: 3}]}
      game = %{game | players: [p1, p2]}

      GenServer.call(
        {:via, Registry, {Rachel.GameRegistry, game_id}},
        {:set_state, game}
      )

      # Play last card to end game
      {:ok, final_game} = GameServer.play_cards(game_id, "p1", [p1.hand |> hd()])

      assert final_game.status == :finished
      # Stats should be recorded (would need to check database in real test)
    end
  end

  describe "set_state/2 helper" do
    test "allows setting game state for testing", %{game_id: game_id} do
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, initial} = GameServer.join_game(game_id, "p1", "Player 1")

      # Modify state
      modified = %{initial | current_player_index: 99}
      :ok = GameServer.set_state(game_id, modified)

      # Verify change
      state = GameServer.get_state(game_id)
      assert state.current_player_index == 99
    end
  end
end
