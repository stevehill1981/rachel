defmodule Rachel.Tournaments.TournamentMatchTest do
  use Rachel.DataCase, async: true

  alias Rachel.Tournaments.{Tournament, TournamentMatch, TournamentPlayer}

  setup do
    {:ok, tournament} =
      Tournament.create_tournament(%{
        name: "Test Tournament",
        format: :single_elimination,
        max_players: 8,
        creator_id: "creator123"
      })

    {:ok, player1} = TournamentPlayer.create_registration(tournament.id, "player1", "Player One")
    {:ok, player2} = TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

    {:ok, tournament: tournament, player1: player1, player2: player2}
  end

  describe "changeset/2" do
    test "validates required fields", %{tournament: _tournament} do
      changeset = TournamentMatch.changeset(%TournamentMatch{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).tournament_id
      assert "can't be blank" in errors_on(changeset).round
      assert "can't be blank" in errors_on(changeset).match_number
    end

    test "validates round is positive", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        round: 0,
        match_number: 1
      }

      changeset = TournamentMatch.changeset(%TournamentMatch{}, attrs)
      assert "must be greater than 0" in errors_on(changeset).round
    end

    test "validates match_number is positive", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        round: 1,
        match_number: 0
      }

      changeset = TournamentMatch.changeset(%TournamentMatch{}, attrs)
      assert "must be greater than 0" in errors_on(changeset).match_number
    end

    test "validates players are different", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        round: 1,
        match_number: 1,
        player1_id: "player1",
        player2_id: "player1"
      }

      changeset = TournamentMatch.changeset(%TournamentMatch{}, attrs)
      assert "cannot be the same as player1" in errors_on(changeset).player2_id
    end

    test "validates winner is one of the players", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        round: 1,
        match_number: 1,
        player1_id: "player1",
        player2_id: "player2",
        winner_id: "different_player"
      }

      changeset = TournamentMatch.changeset(%TournamentMatch{}, attrs)
      assert "must be one of the match players" in errors_on(changeset).winner_id
    end
  end

  describe "create_match/1" do
    test "creates match with valid attrs", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        round: 1,
        match_number: 1,
        player1_id: "player1",
        player2_id: "player2"
      }

      assert {:ok, match} = TournamentMatch.create_match(attrs)
      assert match.tournament_id == tournament.id
      assert match.round == 1
      assert match.match_number == 1
      assert match.player1_id == "player1"
      assert match.player2_id == "player2"
      assert match.status == :pending
    end

    test "fails with invalid attrs" do
      assert {:error, changeset} = TournamentMatch.create_match(%{})
      refute changeset.valid?
    end
  end

  describe "start_match/2" do
    test "starts pending match", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2"
        })

      assert {:ok, updated_match} = TournamentMatch.start_match(match.id, "game123")
      assert updated_match.status == :in_progress
      assert updated_match.game_id == "game123"
      assert updated_match.started_at != nil
    end

    test "starts match without game_id", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2"
        })

      assert {:ok, updated_match} = TournamentMatch.start_match(match.id)
      assert updated_match.status == :in_progress
      assert updated_match.game_id == nil
      assert updated_match.started_at != nil
    end

    test "fails when match not found" do
      assert {:error, :not_found} = TournamentMatch.start_match(999)
    end

    test "fails when match not pending", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :completed
        })

      assert {:error, :match_not_pending} = TournamentMatch.start_match(match.id)
    end
  end

  describe "complete_match/3" do
    test "completes match with valid winner", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :in_progress
        })

      score = %{player1: 15, player2: 12}

      assert {:ok, updated_match} = TournamentMatch.complete_match(match.id, "player1", score)
      assert updated_match.status == :completed
      assert updated_match.winner_id == "player1"
      assert updated_match.loser_id == "player2"
      assert updated_match.score == score
      assert updated_match.completed_at != nil
    end

    test "completes pending match", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :pending
        })

      assert {:ok, updated_match} = TournamentMatch.complete_match(match.id, "player2")
      assert updated_match.status == :completed
      assert updated_match.winner_id == "player2"
      assert updated_match.loser_id == "player1"
    end

    test "fails when match not found" do
      assert {:error, :not_found} = TournamentMatch.complete_match(999, "player1")
    end

    test "fails with invalid winner", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :in_progress
        })

      assert {:error, :invalid_winner} =
               TournamentMatch.complete_match(match.id, "different_player")
    end

    test "fails when match not active", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :completed
        })

      assert {:error, :match_not_active} = TournamentMatch.complete_match(match.id, "player1")
    end
  end

  describe "cancel_match/2" do
    test "cancels pending match", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :pending
        })

      assert {:ok, updated_match} = TournamentMatch.cancel_match(match.id, "Player unavailable")
      assert updated_match.status == :cancelled
      assert updated_match.metadata.cancellation_reason == "Player unavailable"
    end

    test "cancels match without reason", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :pending
        })

      assert {:ok, updated_match} = TournamentMatch.cancel_match(match.id)
      assert updated_match.status == :cancelled
    end

    test "fails when match not found" do
      assert {:error, :not_found} = TournamentMatch.cancel_match(999)
    end

    test "fails when match cannot be cancelled", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :completed
        })

      assert {:error, :cannot_cancel} = TournamentMatch.cancel_match(match.id)
    end
  end

  describe "get_round_matches/3" do
    test "returns matches for specific round", %{tournament: tournament} do
      {:ok, match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2"
        })

      {:ok, match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4"
        })

      {:ok, _match3} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 2,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player3"
        })

      matches = TournamentMatch.get_round_matches(tournament.id, 1)

      assert length(matches) == 2
      match_ids = Enum.map(matches, & &1.id)
      assert match1.id in match_ids
      assert match2.id in match_ids
    end

    test "filters by bracket_type", %{tournament: tournament} do
      {:ok, match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          bracket_type: :winners
        })

      {:ok, _match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4",
          bracket_type: :losers
        })

      matches = TournamentMatch.get_round_matches(tournament.id, 1, :winners)

      assert length(matches) == 1
      assert hd(matches).id == match1.id
    end
  end

  describe "round_completed?/3" do
    test "returns true when all matches completed", %{tournament: tournament} do
      {:ok, _match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :completed
        })

      {:ok, _match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4",
          status: :completed
        })

      assert TournamentMatch.round_completed?(tournament.id, 1) == true
    end

    test "returns false when matches incomplete", %{tournament: tournament} do
      {:ok, _match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :completed
        })

      {:ok, _match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4",
          status: :pending
        })

      assert TournamentMatch.round_completed?(tournament.id, 1) == false
    end
  end

  describe "get_round_winners/3" do
    test "returns winners from completed round", %{tournament: tournament} do
      {:ok, _match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          winner_id: "player1",
          status: :completed
        })

      {:ok, _match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4",
          winner_id: "player4",
          status: :completed
        })

      winners = TournamentMatch.get_round_winners(tournament.id, 1)

      assert length(winners) == 2
      assert "player1" in winners
      assert "player4" in winners
    end

    test "excludes incomplete matches", %{tournament: tournament} do
      {:ok, _match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          winner_id: "player1",
          status: :completed
        })

      {:ok, _match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4",
          status: :pending
        })

      winners = TournamentMatch.get_round_winners(tournament.id, 1)

      assert length(winners) == 1
      assert hd(winners) == "player1"
    end
  end

  describe "award_bye/4" do
    test "creates bye match successfully", %{tournament: tournament} do
      assert {:ok, match} = TournamentMatch.award_bye(tournament.id, 1, 1, "player1")

      assert match.tournament_id == tournament.id
      assert match.round == 1
      assert match.match_number == 1
      assert match.player1_id == "player1"
      assert match.player2_id == nil
      assert match.winner_id == "player1"
      assert match.status == :completed
      assert match.metadata.is_bye == true
    end
  end

  describe "get_upcoming_matches/2" do
    test "returns matches scheduled soon", %{tournament: tournament} do
      # 30 minutes from now
      future_time = DateTime.add(DateTime.utc_now(), 30 * 60, :second)

      {:ok, match1} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          scheduled_time: future_time,
          status: :pending
        })

      # Too far in future
      # 2 hours from now
      far_future = DateTime.add(DateTime.utc_now(), 120 * 60, :second)

      {:ok, _match2} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 2,
          player1_id: "player3",
          player2_id: "player4",
          scheduled_time: far_future,
          status: :pending
        })

      upcoming = TournamentMatch.get_upcoming_matches(tournament.id, 60)

      assert length(upcoming) == 1
      assert hd(upcoming).id == match1.id
    end
  end

  describe "reschedule_match/2" do
    test "reschedules pending match", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :pending
        })

      # 1 hour from now, truncated to second precision
      new_time =
        DateTime.add(DateTime.utc_now(), 60 * 60, :second)
        |> DateTime.truncate(:second)

      assert {:ok, updated_match} = TournamentMatch.reschedule_match(match.id, new_time)
      assert DateTime.truncate(updated_match.scheduled_time, :second) == new_time
    end

    test "fails when match not found" do
      new_time = DateTime.add(DateTime.utc_now(), 60 * 60, :second)

      assert {:error, :not_found} = TournamentMatch.reschedule_match(999, new_time)
    end

    test "fails when match not pending", %{tournament: tournament} do
      {:ok, match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :in_progress
        })

      new_time = DateTime.add(DateTime.utc_now(), 60 * 60, :second)

      assert {:error, :cannot_reschedule} = TournamentMatch.reschedule_match(match.id, new_time)
    end
  end
end
