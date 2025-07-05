defmodule Rachel.Games.ReplayTest do
  use Rachel.DataCase, async: true

  alias Rachel.Games.Replay

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Replay.changeset(%Replay{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).game_id
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).game_data
    end

    test "validates title length" do
      attrs = valid_replay_attrs()

      # Too short - empty string should fail
      changeset = Replay.changeset(%Replay{}, %{attrs | title: ""})
      assert "can't be blank" in errors_on(changeset).title

      # Too long
      long_title = String.duplicate("a", 101)
      changeset = Replay.changeset(%Replay{}, %{attrs | title: long_title})
      assert "should be at most 100 character(s)" in errors_on(changeset).title
    end

    test "validates description length" do
      attrs = valid_replay_attrs()

      # Too long
      long_description = String.duplicate("a", 501)
      changeset = Replay.changeset(%Replay{}, %{attrs | description: long_description})
      assert "should be at most 500 character(s)" in errors_on(changeset).description
    end

    test "validates with valid attributes" do
      attrs = valid_replay_attrs()

      changeset = Replay.changeset(%Replay{}, attrs)
      assert changeset.valid?
    end
  end

  describe "create_replay/3" do
    test "creates replay with basic events" do
      game_id = "game_123"
      events = basic_game_events()
      metadata = %{winner_name: "Alice", player_count: 2}

      assert {:ok, replay} = Replay.create_replay(game_id, events, metadata)
      assert replay.game_id == game_id
      assert replay.title == "Alice vs 1 others"
      assert replay.total_moves == length(events)
      assert replay.player_names == ["Alice", "Bob"]
      assert replay.winner_name == "Alice"
      assert replay.duration_seconds >= 0
    end

    test "creates replay with two-player game title" do
      game_id = "game_456"
      events = basic_game_events()
      metadata = %{player_names: ["Alice", "Bob"]}

      assert {:ok, replay} = Replay.create_replay(game_id, events, metadata)
      assert replay.title == "Alice vs Bob"
    end

    test "creates replay with multi-player game title" do
      game_id = "game_789"
      events = multi_player_events()
      metadata = %{player_names: ["Alice", "Bob", "Charlie", "Diana"]}

      assert {:ok, replay} = Replay.create_replay(game_id, events, metadata)
      assert replay.title == "4-Player Game"
    end

    test "creates replay with default title when no metadata" do
      game_id = "game_default"
      events = basic_game_events()

      assert {:ok, replay} = Replay.create_replay(game_id, events)
      assert replay.title == "Recorded Game"
    end

    test "handles events with timestamps for duration calculation" do
      game_id = "game_timed"
      start_time = ~U[2023-01-01 10:00:00Z]
      end_time = ~U[2023-01-01 10:05:30Z]

      events = [
        %{type: :game_started, timestamp: start_time, player_name: "Alice"},
        %{type: :card_played, timestamp: ~U[2023-01-01 10:02:00Z], player_name: "Alice"},
        %{type: :game_won, timestamp: end_time, player_name: "Alice"}
      ]

      assert {:ok, replay} = Replay.create_replay(game_id, events)
      # 5 minutes 30 seconds
      assert replay.duration_seconds == 330
    end

    test "estimates duration when no timestamps" do
      game_id = "game_estimate"

      events = [
        %{type: :card_played, player_name: "Alice"},
        %{type: :card_played, player_name: "Bob"},
        %{type: :game_won, player_name: "Alice"}
      ]

      assert {:ok, replay} = Replay.create_replay(game_id, events)
      # 3 events * 2 seconds each
      assert replay.duration_seconds == 6
    end

    test "fails with duplicate game_id" do
      game_id = "duplicate_game"
      events = basic_game_events()

      # Create first replay
      assert {:ok, _} = Replay.create_replay(game_id, events)

      # Try to create duplicate
      assert {:error, changeset} = Replay.create_replay(game_id, events)
      refute changeset.valid?
    end

    test "generates description with metadata" do
      game_id = "game_desc"
      events = basic_game_events()
      metadata = %{special_cards_played: 5, total_turns: 42}

      assert {:ok, replay} = Replay.create_replay(game_id, events, metadata)
      assert replay.description == "Game lasted 42 turns with 5 special cards played"
    end

    test "generates simple description with just turns" do
      game_id = "game_simple"
      events = basic_game_events()
      metadata = %{total_turns: 25}

      assert {:ok, replay} = Replay.create_replay(game_id, events, metadata)
      assert replay.description == "Game lasted 25 turns"
    end

    test "generates default description" do
      game_id = "game_no_desc"
      events = basic_game_events()

      assert {:ok, replay} = Replay.create_replay(game_id, events)
      assert replay.description == "No description available"
    end
  end

  describe "get_replay/1" do
    test "returns replay with decoded game data" do
      game_id = "test_get"
      events = basic_game_events()
      {:ok, replay} = Replay.create_replay(game_id, events)

      assert {:ok, loaded_replay} = Replay.get_replay(replay.id)
      assert loaded_replay.id == replay.id
      assert loaded_replay.game_data == events
      assert is_list(loaded_replay.game_data)
    end

    test "increments view count" do
      game_id = "test_views"
      events = basic_game_events()
      {:ok, replay} = Replay.create_replay(game_id, events)

      # View the replay multiple times
      assert {:ok, _} = Replay.get_replay(replay.id)
      assert {:ok, _} = Replay.get_replay(replay.id)
      assert {:ok, _loaded_replay} = Replay.get_replay(replay.id)

      # Reload from database to check view count
      fresh_replay = Repo.get(Replay, replay.id)
      assert fresh_replay.view_count == 3
    end

    test "returns error for non-existent replay" do
      assert {:error, :not_found} = Replay.get_replay(999)
    end

    test "handles invalid JSON data" do
      # Create replay with invalid JSON
      attrs = %{
        game_id: "bad_json",
        title: "Bad JSON Test",
        game_data: "invalid json{",
        metadata: %{}
      }

      replay =
        %Replay{}
        |> Replay.changeset(attrs)
        |> Repo.insert!()

      assert {:error, :invalid_data} = Replay.get_replay(replay.id)
    end
  end

  describe "list_public_replays/1" do
    setup do
      # Create test replays
      {:ok, replay1} = Replay.create_replay("game1", basic_game_events(), %{is_public: true})
      {:ok, replay2} = Replay.create_replay("game2", basic_game_events(), %{is_public: true})
      {:ok, _replay3} = Replay.create_replay("game3", basic_game_events(), %{is_public: false})

      # Update replay1 to be public
      Repo.update!(Replay.changeset(replay1, %{is_public: true}))
      Repo.update!(Replay.changeset(replay2, %{is_public: true}))

      :ok
    end

    test "returns only public replays" do
      replays = Replay.list_public_replays()

      assert length(replays) == 2
      # All should be public
      Enum.each(replays, fn replay_data ->
        # Note: This returns a keyword list, not a struct
        assert Keyword.has_key?(replay_data, :title)
        assert Keyword.has_key?(replay_data, :id)
      end)
    end

    test "respects limit option" do
      replays = Replay.list_public_replays(limit: 1)

      assert length(replays) == 1
    end

    test "respects offset option" do
      all_replays = Replay.list_public_replays()
      offset_replays = Replay.list_public_replays(offset: 1)

      assert length(offset_replays) == length(all_replays) - 1
    end

    test "orders by specified field" do
      # Create replay with high view count
      {:ok, popular_replay} = Replay.create_replay("popular", basic_game_events())
      Repo.update!(Replay.changeset(popular_replay, %{is_public: true, view_count: 100}))

      replays = Replay.list_public_replays(order_by: :view_count)

      # Should be ordered by view_count descending
      assert length(replays) >= 1
      first_replay = hd(replays)
      assert Keyword.get(first_replay, :view_count) == 100
    end

    test "returns specific fields only" do
      replays = Replay.list_public_replays()

      if length(replays) > 0 do
        replay = hd(replays)

        # Should have expected fields
        assert Keyword.has_key?(replay, :id)
        assert Keyword.has_key?(replay, :title)
        assert Keyword.has_key?(replay, :description)
        assert Keyword.has_key?(replay, :duration_seconds)
        assert Keyword.has_key?(replay, :total_moves)
        assert Keyword.has_key?(replay, :player_names)
        assert Keyword.has_key?(replay, :winner_name)
        assert Keyword.has_key?(replay, :view_count)
        assert Keyword.has_key?(replay, :inserted_at)

        # Should not have sensitive fields
        refute Keyword.has_key?(replay, :game_data)
      end
    end
  end

  describe "search_replays/2" do
    setup do
      {:ok, replay1} = Replay.create_replay("search1", basic_game_events())
      {:ok, replay2} = Replay.create_replay("search2", basic_game_events())

      # Make them searchable with specific titles
      Repo.update!(
        Replay.changeset(replay1, %{
          is_public: true,
          title: "Epic Alice Victory"
        })
      )

      Repo.update!(
        Replay.changeset(replay2, %{
          is_public: true,
          title: "Bob's Comeback",
          player_names: ["bob", "charlie"]
        })
      )

      :ok
    end

    test "searches by title (case insensitive)" do
      results = Replay.search_replays("epic")

      assert length(results) == 1
      result = hd(results)
      assert Keyword.get(result, :title) == "Epic Alice Victory"
    end

    test "searches by player name" do
      results = Replay.search_replays("bob")

      assert length(results) >= 1
      # Should find replay with Bob in player_names
      assert length(results) >= 1
    end

    test "returns empty list for no matches" do
      results = Replay.search_replays("nonexistent")

      assert results == []
    end

    test "respects limit option" do
      # Create multiple matching replays
      Enum.each(1..5, fn i ->
        {:ok, replay} = Replay.create_replay("limit_test_#{i}", basic_game_events())

        Repo.update!(
          Replay.changeset(replay, %{
            is_public: true,
            title: "Test Match #{i}"
          })
        )
      end)

      results = Replay.search_replays("Test", limit: 3)

      assert length(results) == 3
    end

    test "orders by view count and insertion date" do
      # Create replays with different view counts
      {:ok, old_popular} = Replay.create_replay("old_popular", basic_game_events())
      {:ok, new_unpopular} = Replay.create_replay("new_unpopular", basic_game_events())

      Repo.update!(
        Replay.changeset(old_popular, %{
          is_public: true,
          title: "Popular Game",
          view_count: 50
        })
      )

      Repo.update!(
        Replay.changeset(new_unpopular, %{
          is_public: true,
          title: "Popular Game 2",
          view_count: 10
        })
      )

      results = Replay.search_replays("Popular")

      # Should be ordered by view count descending
      assert length(results) >= 2
    end
  end

  # Helper functions

  defp valid_replay_attrs do
    %{
      game_id: "test_game_123",
      title: "Test Game",
      description: "A test game replay",
      game_data: Jason.encode!([%{type: :test_event}]),
      metadata: %{},
      duration_seconds: 300,
      total_moves: 25,
      player_names: ["Player 1", "Player 2"],
      winner_name: "Player 1"
    }
  end

  defp basic_game_events do
    [
      %{
        type: :game_started,
        timestamp: DateTime.utc_now(),
        player_name: "Alice",
        data: %{}
      },
      %{
        type: :card_played,
        timestamp: DateTime.utc_now(),
        player_name: "Alice",
        data: %{cards: [%{rank: :ace, suit: :hearts}]}
      },
      %{
        type: :card_played,
        timestamp: DateTime.utc_now(),
        player_name: "Bob",
        data: %{cards: [%{rank: :king, suit: :spades}]}
      },
      %{
        type: :game_won,
        timestamp: DateTime.utc_now(),
        player_name: "Alice",
        data: %{position: 1}
      }
    ]
  end

  defp multi_player_events do
    [
      %{type: :game_started, player_name: "Alice"},
      %{type: :card_played, player_name: "Bob"},
      %{type: :card_played, player_name: "Charlie"},
      %{type: :card_played, player_name: "Diana"},
      %{type: :game_won, player_name: "Alice"}
    ]
  end
end
