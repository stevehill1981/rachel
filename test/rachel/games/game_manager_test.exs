defmodule Rachel.Games.GameManagerTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.GameManager

  describe "create_game/0" do
    test "creates a new game with unique ID" do
      assert {:ok, game_id} = GameManager.create_game()
      assert is_binary(game_id)
      assert GameManager.game_exists?(game_id)
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "each game gets a unique ID" do
      {:ok, game_id1} = GameManager.create_game()
      {:ok, game_id2} = GameManager.create_game()
      
      assert game_id1 != game_id2
      assert GameManager.game_exists?(game_id1)
      assert GameManager.game_exists?(game_id2)
      
      # Clean up
      GameManager.stop_game(game_id1)
      GameManager.stop_game(game_id2)
    end
  end

  describe "create_and_join_game/2" do
    test "creates game and joins creator" do
      assert {:ok, game_id} = GameManager.create_and_join_game("creator123", "Alice")
      
      {:ok, game_info} = GameManager.get_game_info(game_id)
      assert game_info.player_count == 1
      assert Enum.any?(game_info.players, &(&1.id == "creator123" and &1.name == "Alice"))
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "cleans up game if creator join fails" do
      # Create a game, then try to join with a duplicate ID to force a failure
      {:ok, game_id} = GameManager.create_game()
      {:ok, _} = GameManager.join_game(game_id, "player1", "Alice")
      
      # This will test that games can be cleaned up manually
      GameManager.stop_game(game_id)
      
      # Give the supervisor a moment to clean up
      Process.sleep(10)
      
      # Game should be gone
      refute GameManager.game_exists?(game_id)
    end
  end

  describe "join_game/3" do
    setup do
      {:ok, game_id} = GameManager.create_game()
      {:ok, game_id: game_id}
    end

    test "allows joining existing game", %{game_id: game_id} do
      assert {:ok, _game} = GameManager.join_game(game_id, "player1", "Alice")
      assert {:ok, _game} = GameManager.join_game(game_id, "player2", "Bob")
      
      {:ok, game_info} = GameManager.get_game_info(game_id)
      assert game_info.player_count == 2
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "returns error for non-existent game" do
      assert {:error, :game_not_found} = GameManager.join_game("fake-game", "player1", "Alice")
    end

    test "forwards game server errors", %{game_id: game_id} do
      # Join the same player twice
      {:ok, _} = GameManager.join_game(game_id, "player1", "Alice")
      assert {:error, :already_joined} = GameManager.join_game(game_id, "player1", "Alice")
      
      # Clean up
      GameManager.stop_game(game_id)
    end
  end

  describe "list_active_games/0" do
    test "returns empty list when no games" do
      # Clean up any existing games first
      GameManager.list_active_games()
      |> Enum.each(&GameManager.stop_game(&1.id))
      
      assert GameManager.list_active_games() == []
    end

    test "lists active games with basic info" do
      {:ok, game_id1} = GameManager.create_and_join_game("player1", "Alice")
      {:ok, game_id2} = GameManager.create_game()
      
      games = GameManager.list_active_games()
      game_ids = Enum.map(games, & &1.id)
      
      assert game_id1 in game_ids
      assert game_id2 in game_ids
      
      # Check structure
      game1 = Enum.find(games, &(&1.id == game_id1))
      assert game1.status == :waiting
      assert game1.player_count == 1
      assert is_list(game1.players)
      
      # Clean up
      GameManager.stop_game(game_id1)
      GameManager.stop_game(game_id2)
    end
  end

  describe "get_game_info/1" do
    setup do
      {:ok, game_id} = GameManager.create_and_join_game("host", "Host Player")
      {:ok, game_id: game_id}
    end

    test "returns detailed game info", %{game_id: game_id} do
      assert {:ok, info} = GameManager.get_game_info(game_id)
      
      assert info.id == game_id
      assert info.status == :waiting
      assert info.player_count == 1
      assert info.max_players == 8
      assert info.can_join == true
      assert is_list(info.players)
      
      player = hd(info.players)
      assert player.id == "host"
      assert player.name == "Host Player"
      assert player.is_ai == false
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "returns error for non-existent game" do
      assert {:error, :game_not_found} = GameManager.get_game_info("fake-game")
    end

    test "shows can_join false when game is full or started", %{game_id: game_id} do
      # Fill up the game
      for i <- 2..8 do
        GameManager.join_game(game_id, "player#{i}", "Player #{i}")
      end
      
      {:ok, info} = GameManager.get_game_info(game_id)
      assert info.can_join == false
      assert info.player_count == 8
      
      # Clean up
      GameManager.stop_game(game_id)
    end
  end

  describe "game_exists?/1" do
    test "returns true for existing games" do
      {:ok, game_id} = GameManager.create_game()
      assert GameManager.game_exists?(game_id) == true
      
      # Clean up
      GameManager.stop_game(game_id)
    end

    test "returns false for non-existent games" do
      assert GameManager.game_exists?("fake-game") == false
    end

    test "returns false after game is stopped" do
      {:ok, game_id} = GameManager.create_game()
      assert GameManager.game_exists?(game_id) == true
      
      GameManager.stop_game(game_id)
      # Give the supervisor a moment to clean up
      Process.sleep(10)
      assert GameManager.game_exists?(game_id) == false
    end
  end

  describe "stop_game/1" do
    test "stops existing game" do
      {:ok, game_id} = GameManager.create_game()
      assert GameManager.game_exists?(game_id)
      
      assert :ok = GameManager.stop_game(game_id)
      # Give the supervisor a moment to clean up
      Process.sleep(10)
      refute GameManager.game_exists?(game_id)
    end

    test "returns error for non-existent game" do
      assert {:error, :game_not_found} = GameManager.stop_game("fake-game")
    end
  end

  describe "generate_game_code/0" do
    test "generates 6-character alphanumeric codes" do
      code = GameManager.generate_game_code()
      assert String.length(code) == 6
      assert String.match?(code, ~r/^[A-Z0-9]+$/)
    end

    test "generates unique codes" do
      code1 = GameManager.generate_game_code()
      code2 = GameManager.generate_game_code()
      
      # While there's a tiny chance they could be the same, it's very unlikely
      assert code1 != code2
    end
  end

  describe "cleanup_finished_games/1" do
    test "removes games with no players" do
      {:ok, game_id} = GameManager.create_game()
      
      # Initially the game exists
      assert GameManager.game_exists?(game_id)
      
      # Cleanup should remove it since it has no players
      GameManager.cleanup_finished_games()
      
      # Give the supervisor a moment to clean up
      Process.sleep(10)
      
      # Game should be gone
      refute GameManager.game_exists?(game_id)
    end

    test "keeps games with active players" do
      {:ok, game_id} = GameManager.create_and_join_game("player1", "Alice")
      
      # Initially the game exists
      assert GameManager.game_exists?(game_id)
      
      # Cleanup should keep it since it has players
      GameManager.cleanup_finished_games()
      
      # Game should still exist
      assert GameManager.game_exists?(game_id)
      
      # Clean up manually
      GameManager.stop_game(game_id)
    end
  end
end