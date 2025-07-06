defmodule Rachel.Games.ReplayRecorderTest do
  use Rachel.DataCase, async: true
  
  @moduletag :skip

  alias Rachel.Games.ReplayRecorder

  setup do
    # Clean up any existing ETS tables from previous tests
    game_id = "test_game_#{System.unique_integer()}"

    on_exit(fn ->
      table_name = :"replay_#{game_id}"

      if :ets.whereis(table_name) != :undefined do
        :ets.delete(table_name)
      end
    end)

    {:ok, game_id: game_id}
  end

  describe "start_recording/2" do
    test "starts recording with initial game state", %{game_id: game_id} do
      initial_state = %{
        players: [
          %{id: "p1", name: "Alice", is_ai: false, hand: [%{}, %{}]},
          %{id: "p2", name: "Bob", is_ai: true, hand: [%{}, %{}, %{}]}
        ],
        status: :playing,
        direction: :clockwise,
        current_player_index: 0,
        pending_pickups: 0,
        pending_skips: 0,
        nominated_suit: nil
      }

      assert {:ok, events} = ReplayRecorder.start_recording(game_id, initial_state)

      assert length(events) == 1
      event = hd(events)
      assert event.type == :game_started
      assert event.player_id == nil
      assert event.player_name == nil
      assert event.data.game_id == game_id
      assert length(event.data.players) == 2

      # Check player info extraction
      alice = Enum.find(event.data.players, &(&1.id == "p1"))
      assert alice.name == "Alice"
      assert alice.is_ai == false
      assert alice.hand_size == 2

      bob = Enum.find(event.data.players, &(&1.id == "p2"))
      assert bob.name == "Bob"
      assert bob.is_ai == true
      assert bob.hand_size == 3

      # Check game state sanitization
      assert event.data.game_state.status == :playing
      assert event.data.game_state.direction == :clockwise
      assert event.data.game_state.current_player_index == 0
    end

    test "creates ETS table for the game", %{game_id: game_id} do
      initial_state = basic_game_state()

      assert {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # Check ETS table exists
      table_name = :"replay_#{game_id}"
      assert :ets.whereis(table_name) != :undefined

      # Check initial events are stored
      assert [{0, events}] = :ets.lookup(table_name, 0)
      assert length(events) == 1
    end
  end

  describe "record_event/5" do
    test "records event when recording is active", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      assert {:ok, event} =
               ReplayRecorder.record_event(
                 game_id,
                 :card_played,
                 "p1",
                 "Alice",
                 %{cards: [%{rank: :ace, suit: :hearts}]}
               )

      assert event.type == :card_played
      assert event.player_id == "p1"
      assert event.player_name == "Alice"
      assert event.data.cards == [%{rank: :ace, suit: :hearts}]
      assert %DateTime{} = event.timestamp
    end

    test "fails when recording not started", %{game_id: game_id} do
      assert {:error, :recording_not_started} =
               ReplayRecorder.record_event(
                 game_id,
                 :card_played,
                 "p1",
                 "Alice",
                 %{}
               )
    end

    test "accumulates events in order", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # Record multiple events
      {:ok, _} = ReplayRecorder.record_event(game_id, :card_played, "p1", "Alice", %{card: 1})
      {:ok, _} = ReplayRecorder.record_event(game_id, :card_drawn, "p2", "Bob", %{count: 2})

      {:ok, _} =
        ReplayRecorder.record_event(game_id, :suit_nominated, "p1", "Alice", %{suit: :hearts})

      # Get current events
      {:ok, events} = ReplayRecorder.get_current_events(game_id)

      # 1 start + 3 recorded
      assert length(events) == 4
      assert Enum.at(events, 0).type == :game_started
      assert Enum.at(events, 1).type == :card_played
      assert Enum.at(events, 2).type == :card_drawn
      assert Enum.at(events, 3).type == :suit_nominated
    end
  end

  describe "stop_recording/2" do
    test "stops recording and returns events", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # Record some events
      {:ok, _} = ReplayRecorder.record_event(game_id, :card_played, "p1", "Alice", %{})
      {:ok, _} = ReplayRecorder.record_event(game_id, :game_won, "p1", "Alice", %{})

      assert {:ok, events} = ReplayRecorder.stop_recording(game_id, false)

      assert length(events) == 3
      assert hd(events).type == :game_started
      assert List.last(events).type == :game_won

      # ETS table should be deleted
      table_name = :"replay_#{game_id}"
      assert :ets.whereis(table_name) == :undefined
    end

    test "saves replay when save_replay? is true", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # Record enough events to warrant saving
      {:ok, _} = ReplayRecorder.record_event(game_id, :card_played, "p1", "Alice", %{})
      {:ok, _} = ReplayRecorder.record_event(game_id, :game_won, "p1", "Alice", %{})

      assert {:ok, events} = ReplayRecorder.stop_recording(game_id, true)

      # Should save replay to database
      assert length(events) == 3

      # Verify replay was saved (check if it exists in database)
      replay = Repo.get_by(Rachel.Games.Replay, game_id: game_id)
      assert replay != nil
      assert replay.game_id == game_id
    end

    test "doesn't save replay with too few events", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # Only start event, no other events
      assert {:ok, events} = ReplayRecorder.stop_recording(game_id, true)

      assert length(events) == 1

      # Should not save replay with only 1 event
      replay = Repo.get_by(Rachel.Games.Replay, game_id: game_id)
      assert replay == nil
    end

    test "fails when no recording found", %{game_id: game_id} do
      assert {:error, :no_recording_found} = ReplayRecorder.stop_recording(game_id)
    end
  end

  describe "get_current_events/1" do
    test "returns current events without stopping recording", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      {:ok, _} = ReplayRecorder.record_event(game_id, :card_played, "p1", "Alice", %{})

      assert {:ok, events} = ReplayRecorder.get_current_events(game_id)
      assert length(events) == 2

      # Recording should still be active
      {:ok, _} = ReplayRecorder.record_event(game_id, :card_drawn, "p2", "Bob", %{})

      assert {:ok, updated_events} = ReplayRecorder.get_current_events(game_id)
      assert length(updated_events) == 3
    end

    test "fails when no recording found", %{game_id: game_id} do
      assert {:error, :no_recording_found} = ReplayRecorder.get_current_events(game_id)
    end
  end

  describe "specific event recording functions" do
    setup %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)
      :ok
    end

    test "record_card_play/5", %{game_id: game_id} do
      cards = [
        %{rank: :ace, suit: :hearts},
        %{rank: :king, suit: :spades}
      ]

      effects = [:skip_next_player, :reverse_direction]

      assert {:ok, event} =
               ReplayRecorder.record_card_play(
                 game_id,
                 "p1",
                 "Alice",
                 cards,
                 effects
               )

      assert event.type == :card_played
      assert event.player_id == "p1"
      assert event.player_name == "Alice"

      assert event.data.cards == [
               %{rank: :ace, suit: :hearts},
               %{rank: :king, suit: :spades}
             ]

      assert event.data.effects == effects
      assert event.data.card_count == 2
    end

    test "record_card_draw/5", %{game_id: game_id} do
      assert {:ok, event} =
               ReplayRecorder.record_card_draw(
                 game_id,
                 "p2",
                 "Bob",
                 3,
                 :pickup_penalty
               )

      assert event.type == :card_drawn
      assert event.player_id == "p2"
      assert event.player_name == "Bob"
      assert event.data.count == 3
      assert event.data.reason == :pickup_penalty
    end

    test "record_suit_nomination/4", %{game_id: game_id} do
      assert {:ok, event} =
               ReplayRecorder.record_suit_nomination(
                 game_id,
                 "p1",
                 "Alice",
                 :diamonds
               )

      assert event.type == :suit_nominated
      assert event.player_id == "p1"
      assert event.player_name == "Alice"
      assert event.data.suit == :diamonds
    end

    test "record_game_won/5", %{game_id: game_id} do
      final_state = %{
        players: [
          %{id: "p1", name: "Alice", is_ai: false, hand: []},
          %{id: "p2", name: "Bob", is_ai: true, hand: [%{}, %{}]}
        ],
        stats: %{
          game_stats: %{
            total_turns: 25,
            total_cards_played: 50
          }
        }
      }

      assert {:ok, event} =
               ReplayRecorder.record_game_won(
                 game_id,
                 "p1",
                 "Alice",
                 1,
                 final_state
               )

      assert event.type == :game_won
      assert event.player_id == "p1"
      assert event.player_name == "Alice"
      assert event.data.position == 1
      assert length(event.data.remaining_players) == 2
      assert event.data.game_stats.total_turns == 25
    end

    test "record_player_join/4", %{game_id: game_id} do
      assert {:ok, event} =
               ReplayRecorder.record_player_join(
                 game_id,
                 "p3",
                 "Charlie",
                 :spectator
               )

      assert event.type == :player_joined
      assert event.player_id == "p3"
      assert event.player_name == "Charlie"
      assert event.data.join_type == :spectator
    end

    test "record_player_disconnect/3", %{game_id: game_id} do
      assert {:ok, event} =
               ReplayRecorder.record_player_disconnect(
                 game_id,
                 "p2",
                 "Bob"
               )

      assert event.type == :player_disconnected
      assert event.player_id == "p2"
      assert event.player_name == "Bob"
      assert event.data == %{}
    end
  end

  describe "metadata building and helper functions" do
    test "builds comprehensive metadata from events", %{game_id: game_id} do
      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # Record various events to test metadata building
      {:ok, _} = ReplayRecorder.record_card_play(game_id, "p1", "Alice", [%{rank: :ace}], [:skip])
      {:ok, _} = ReplayRecorder.record_card_draw(game_id, "p2", "Bob", 2, :penalty)
      {:ok, _} = ReplayRecorder.record_card_play(game_id, "p2", "Bob", [%{rank: :two}], [:pickup])
      {:ok, _} = ReplayRecorder.record_game_won(game_id, "p1", "Alice", 1, basic_game_state())

      # Stop recording and save replay to trigger metadata building
      assert {:ok, _events} = ReplayRecorder.stop_recording(game_id, true)

      # Verify the replay was created with proper metadata
      replay = Repo.get_by(Rachel.Games.Replay, game_id: game_id)
      assert replay != nil
      assert replay.player_names == ["Alice", "Bob"]
      assert replay.winner_name == "Alice"
    end

    test "handles game state without stats gracefully", %{game_id: game_id} do
      state_without_stats = %{
        players: [%{id: "p1", name: "Alice", is_ai: false, hand: []}],
        status: :finished
      }

      initial_state = basic_game_state()
      {:ok, _} = ReplayRecorder.start_recording(game_id, initial_state)

      # This should not crash even without stats
      assert {:ok, event} =
               ReplayRecorder.record_game_won(
                 game_id,
                 "p1",
                 "Alice",
                 1,
                 state_without_stats
               )

      assert event.data.game_stats == %{}
    end
  end

  # Helper functions

  defp basic_game_state do
    %{
      players: [
        %{id: "p1", name: "Alice", is_ai: false, hand: []},
        %{id: "p2", name: "Bob", is_ai: true, hand: []}
      ],
      status: :playing,
      direction: :clockwise,
      current_player_index: 0,
      pending_pickups: 0,
      pending_skips: 0,
      nominated_suit: nil
    }
  end
end
