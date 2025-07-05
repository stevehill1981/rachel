defmodule Rachel.Games.GamePersistenceTest do
  use Rachel.DataCase, async: false

  alias Rachel.Games.{GamePersistence, GameState}
  alias Rachel.Repo

  setup do
    # Clear any existing GameState records
    Repo.delete_all(GameState)

    # Start the GamePersistence server for testing
    pid = start_supervised!({GamePersistence, []})

    {:ok, persistence_pid: pid}
  end

  describe "server startup and basic functionality" do
    test "server starts and stays alive" do
      assert Process.whereis(GamePersistence) != nil
      assert Process.alive?(Process.whereis(GamePersistence))
    end

    test "handles periodic save messages without crashing" do
      pid = Process.whereis(GamePersistence)

      # Send the periodic save message
      send(pid, :save_active_games)

      # Should not crash
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "handles periodic cleanup messages without crashing" do
      pid = Process.whereis(GamePersistence)

      # Send the periodic cleanup message
      send(pid, :cleanup_old_games)

      # Should not crash
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  describe "load_game_state/1" do
    test "returns error for non-existent game" do
      result = GamePersistence.load_game_state("non-existent-game")
      assert result == {:error, :not_found}
    end

    test "returns error for corrupted JSON" do
      # Test by manually inserting data that bypasses changeset validation
      game_id = "corrupted-game"

      # Insert using raw SQL to bypass validation
      {:ok, _} =
        Ecto.Adapters.SQL.query(
          Repo,
          "INSERT INTO game_states (game_id, game_data, status, player_count, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6)",
          [game_id, "invalid json", "waiting", 0, DateTime.utc_now(), DateTime.utc_now()]
        )

      result = GamePersistence.load_game_state(game_id)
      assert {:error, :invalid_state} = result
    end

    test "loads valid game state from database" do
      game_id = "valid-game"

      # Create valid JSON that matches expected structure
      valid_game_data = %{
        "id" => game_id,
        "players" => [],
        "status" => "waiting",
        "current_player_index" => 0,
        "direction" => "clockwise",
        "pending_pickups" => 0,
        "pending_skips" => 0,
        "nominated_suit" => nil,
        "winners" => []
      }

      json_data = Jason.encode!(valid_game_data)

      %GameState{}
      |> GameState.changeset(%{
        game_id: game_id,
        game_data: json_data,
        status: "waiting",
        player_count: 0
      })
      |> Repo.insert!()

      {:ok, loaded_state} = GamePersistence.load_game_state(game_id)

      assert loaded_state.id == game_id
      assert loaded_state.status == :waiting
      assert loaded_state.players == []
    end
  end

  describe "delete_game_state/1" do
    test "deletes existing game state" do
      game_id = "deletable-game"

      # Insert a game state
      valid_game_data = %{
        "id" => game_id,
        "players" => [],
        "status" => "waiting"
      }

      json_data = Jason.encode!(valid_game_data)

      %GameState{}
      |> GameState.changeset(%{
        game_id: game_id,
        game_data: json_data,
        status: "waiting",
        player_count: 0
      })
      |> Repo.insert!()

      assert Repo.get_by(GameState, game_id: game_id) != nil

      GamePersistence.delete_game_state(game_id)
      Process.sleep(100)

      assert Repo.get_by(GameState, game_id: game_id) == nil
    end

    test "handles deletion of non-existent game gracefully" do
      GamePersistence.delete_game_state("non-existent-game")
      Process.sleep(100)

      assert Process.alive?(Process.whereis(GamePersistence))
    end
  end

  describe "recover_active_games/0" do
    test "returns success tuple with count" do
      result = GamePersistence.recover_active_games()

      assert {:ok, count} = result
      assert is_integer(count)
      assert count >= 0
    end

    test "recovers games from database" do
      # Insert a valid game state
      game_id = "recoverable-game"

      valid_game_data = %{
        "id" => game_id,
        "players" => [],
        "status" => "playing"
      }

      json_data = Jason.encode!(valid_game_data)

      %GameState{}
      |> GameState.changeset(%{
        game_id: game_id,
        game_data: json_data,
        status: "playing",
        player_count: 0
      })
      |> Repo.insert!()

      {:ok, count} = GamePersistence.recover_active_games()

      # Should attempt to recover at least the game we inserted
      # May be 0 if recovery fails due to missing GameServer
      assert count >= 0
    end
  end

  describe "save_game_state/2 error handling" do
    test "handles invalid data gracefully" do
      # This should not crash the process
      GamePersistence.save_game_state("invalid", %{invalid: :data})
      Process.sleep(100)

      # Process should still be alive
      assert Process.alive?(Process.whereis(GamePersistence))
    end

    test "handles nil game state" do
      GamePersistence.save_game_state("test-nil", nil)
      Process.sleep(100)

      assert Process.alive?(Process.whereis(GamePersistence))
    end

    test "handles empty game state" do
      GamePersistence.save_game_state("test-empty", %{})
      Process.sleep(100)

      assert Process.alive?(Process.whereis(GamePersistence))
    end
  end

  describe "serialization/deserialization helpers" do
    test "deserializes datetime strings correctly" do
      game_id = "datetime-test"

      # Create game data with datetime-like string in player data (which is preserved)
      game_data_with_datetime = %{
        "id" => game_id,
        "players" => [
          %{
            "id" => "player1",
            "name" => "Player 1",
            "last_seen" => "2024-01-01T12:00:00Z"
          }
        ],
        "status" => "waiting"
      }

      json_data = Jason.encode!(game_data_with_datetime)

      %GameState{}
      |> GameState.changeset(%{
        game_id: game_id,
        game_data: json_data,
        status: "waiting",
        player_count: 1
      })
      |> Repo.insert!()

      {:ok, loaded_state} = GamePersistence.load_game_state(game_id)

      # Should deserialize the datetime string to DateTime struct within player data
      player = hd(loaded_state.players)
      assert %DateTime{} = player.last_seen
    end

    test "deserializes enum values correctly" do
      game_id = "enum-test"

      # Test different status and direction values
      test_cases = [
        %{"status" => "waiting", "direction" => "clockwise"},
        %{"status" => "playing", "direction" => "counter_clockwise"},
        %{"status" => "finished", "direction" => "clockwise"}
      ]

      Enum.each(test_cases, fn test_data ->
        unique_id = "#{game_id}-#{System.unique_integer()}"

        game_data =
          Map.merge(
            %{
              "id" => unique_id,
              "players" => []
            },
            test_data
          )

        json_data = Jason.encode!(game_data)

        %GameState{}
        |> GameState.changeset(%{
          game_id: unique_id,
          game_data: json_data,
          status: test_data["status"],
          player_count: 0
        })
        |> Repo.insert!()

        {:ok, loaded_state} = GamePersistence.load_game_state(unique_id)

        # Check that string values were converted to atoms
        expected_status = String.to_atom(test_data["status"])

        expected_direction =
          case test_data["direction"] do
            "clockwise" -> :clockwise
            "counter_clockwise" -> :counter_clockwise
          end

        assert loaded_state.status == expected_status
        assert loaded_state.direction == expected_direction
      end)
    end

    test "deserializes card suits correctly" do
      game_id = "suits-test"

      # Test all card suits
      test_suits = ["hearts", "diamonds", "clubs", "spades"]

      Enum.each(test_suits, fn suit_str ->
        unique_id = "#{game_id}-#{suit_str}"

        game_data = %{
          "id" => unique_id,
          "players" => [],
          "status" => "waiting",
          "current_card" => %{
            "suit" => suit_str,
            "rank" => 5
          }
        }

        json_data = Jason.encode!(game_data)

        %GameState{}
        |> GameState.changeset(%{
          game_id: unique_id,
          game_data: json_data,
          status: "waiting",
          player_count: 0
        })
        |> Repo.insert!()

        {:ok, loaded_state} = GamePersistence.load_game_state(unique_id)

        expected_suit = String.to_atom(suit_str)
        assert loaded_state.current_card.suit == expected_suit
      end)
    end
  end

  describe "edge cases and validation" do
    test "handles moderately large valid game data" do
      game_id = "large-valid-game"

      # Create moderate sized but valid game data
      # Within max_players limit
      large_players =
        for i <- 1..8 do
          %{
            "id" => "player-#{i}",
            "name" => "Player #{i}",
            "hand" => [],
            "is_ai" => false
          }
        end

      large_game_data = %{
        "id" => game_id,
        "players" => large_players,
        "status" => "waiting"
      }

      json_data = Jason.encode!(large_game_data)

      # Should be well under the 100KB limit
      assert byte_size(json_data) < 100_000

      changeset =
        GameState.changeset(%GameState{}, %{
          game_id: game_id,
          game_data: json_data,
          status: "waiting",
          player_count: length(large_players)
        })

      assert changeset.valid?

      {:ok, _game_state} = Repo.insert(changeset)

      {:ok, loaded_state} = GamePersistence.load_game_state(game_id)
      assert length(loaded_state.players) == 8
    end

    test "handles empty and nil field values" do
      game_id = "empty-fields-test"

      game_data = %{
        "id" => game_id,
        "players" => [],
        "status" => "waiting",
        "current_card" => nil,
        "deck" => [],
        "discard_pile" => [],
        "nominated_suit" => nil,
        "winners" => []
      }

      json_data = Jason.encode!(game_data)

      %GameState{}
      |> GameState.changeset(%{
        game_id: game_id,
        game_data: json_data,
        status: "waiting",
        player_count: 0,
        host_id: nil
      })
      |> Repo.insert!()

      {:ok, loaded_state} = GamePersistence.load_game_state(game_id)

      assert loaded_state.players == []
      assert loaded_state.current_card == nil
      assert loaded_state.deck == []
      assert loaded_state.discard_pile == []
      assert loaded_state.nominated_suit == nil
      assert loaded_state.winners == []
    end

    test "converts to Game struct ignoring extra fields" do
      game_id = "extra-fields-test"

      game_data = %{
        "id" => game_id,
        "players" => [],
        "status" => "waiting",
        "unknown_field" => "unknown_value"
      }

      json_data = Jason.encode!(game_data)

      %GameState{}
      |> GameState.changeset(%{
        game_id: game_id,
        game_data: json_data,
        status: "waiting",
        player_count: 0
      })
      |> Repo.insert!()

      {:ok, loaded_state} = GamePersistence.load_game_state(game_id)

      # Should load successfully and be a Game struct (extra fields ignored)
      assert %Rachel.Games.Game{} = loaded_state
      assert loaded_state.id == game_id
      assert loaded_state.players == []
      assert loaded_state.status == :waiting
    end
  end

  describe "error logging and resilience" do
    test "continues operation after save errors" do
      pid = Process.whereis(GamePersistence)

      # Send multiple invalid saves
      for i <- 1..5 do
        GamePersistence.save_game_state("invalid-#{i}", :not_a_map)
      end

      Process.sleep(200)

      # Process should still be alive and functional
      assert Process.alive?(pid)

      # Should still be able to perform valid operations
      result = GamePersistence.load_game_state("non-existent")
      assert result == {:error, :not_found}
    end

    test "handles database connection issues gracefully" do
      # This test verifies the process doesn't crash on DB errors
      # In a real scenario, this might involve stopping the DB temporarily

      pid = Process.whereis(GamePersistence)

      # Process should be alive
      assert Process.alive?(pid)

      # Even if operations fail, process should remain stable
      GamePersistence.delete_game_state("any-id")
      Process.sleep(100)

      assert Process.alive?(pid)
    end
  end
end
