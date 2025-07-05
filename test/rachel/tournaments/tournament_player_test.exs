defmodule Rachel.Tournaments.TournamentPlayerTest do
  use Rachel.DataCase, async: true

  alias Rachel.Repo
  alias Rachel.Tournaments.{Tournament, TournamentPlayer}

  setup do
    {:ok, tournament} =
      Tournament.create_tournament(%{
        name: "Test Tournament",
        format: :single_elimination,
        max_players: 8,
        creator_id: "creator123"
      })

    {:ok, tournament: tournament}
  end

  describe "changeset/2" do
    test "validates required fields", %{tournament: _tournament} do
      changeset = TournamentPlayer.changeset(%TournamentPlayer{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).tournament_id
      assert "can't be blank" in errors_on(changeset).player_id
      assert "can't be blank" in errors_on(changeset).player_name
    end

    test "validates player_name length", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        player_id: "player1",
        player_name: ""
      }

      changeset = TournamentPlayer.changeset(%TournamentPlayer{}, attrs)
      assert "should be at least 1 character(s)" in errors_on(changeset).player_name

      # Too long
      long_name = String.duplicate("a", 51)
      attrs = %{attrs | player_name: long_name}
      changeset = TournamentPlayer.changeset(%TournamentPlayer{}, attrs)
      assert "should be at most 50 character(s)" in errors_on(changeset).player_name
    end

    test "validates seed is positive", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        player_id: "player1",
        player_name: "Player One",
        seed: 0
      }

      changeset = TournamentPlayer.changeset(%TournamentPlayer{}, attrs)
      assert "must be greater than 0" in errors_on(changeset).seed
    end

    test "validates numeric fields are non-negative", %{tournament: tournament} do
      attrs = %{
        tournament_id: tournament.id,
        player_id: "player1",
        player_name: "Player One",
        points: -1,
        wins: -1,
        losses: -1,
        byes: -1
      }

      changeset = TournamentPlayer.changeset(%TournamentPlayer{}, attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).points
      assert "must be greater than or equal to 0" in errors_on(changeset).wins
      assert "must be greater than or equal to 0" in errors_on(changeset).losses
      assert "must be greater than or equal to 0" in errors_on(changeset).byes
    end
  end

  describe "create_registration/4" do
    test "creates player registration with valid attrs", %{tournament: tournament} do
      assert {:ok, player} =
               TournamentPlayer.create_registration(
                 tournament.id,
                 "player1",
                 "Player One"
               )

      assert player.tournament_id == tournament.id
      assert player.player_id == "player1"
      assert player.player_name == "Player One"
      assert player.status == :registered
      assert player.points == 0
      assert player.wins == 0
      assert player.losses == 0
      assert player.byes == 0
    end

    test "creates registration with optional seed", %{tournament: tournament} do
      assert {:ok, player} =
               TournamentPlayer.create_registration(
                 tournament.id,
                 "player1",
                 "Player One",
                 seed: 3
               )

      assert player.seed == 3
    end

    test "creates registration with metadata", %{tournament: tournament} do
      metadata = %{rating: 1500, country: "US"}

      assert {:ok, player} =
               TournamentPlayer.create_registration(
                 tournament.id,
                 "player1",
                 "Player One",
                 metadata: metadata
               )

      assert player.metadata == metadata
    end

    test "fails with invalid tournament_id" do
      assert {:error, changeset} =
               TournamentPlayer.create_registration(
                 999,
                 "player1",
                 "Player One"
               )

      refute changeset.valid?
    end
  end

  describe "update_status/4" do
    test "updates player status successfully", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.update_status(
                 tournament.id,
                 "player1",
                 :checked_in
               )

      assert updated_player.status == :checked_in
    end

    test "updates status with eliminated_round", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.update_status(
                 tournament.id,
                 "player1",
                 :eliminated,
                 eliminated_round: 2
               )

      assert updated_player.status == :eliminated
      assert updated_player.eliminated_round == 2
    end

    test "updates status with final_position", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.update_status(
                 tournament.id,
                 "player1",
                 :eliminated,
                 final_position: 3
               )

      assert updated_player.status == :eliminated
      assert updated_player.final_position == 3
    end

    test "fails when player not found", %{tournament: tournament} do
      assert {:error, :not_found} =
               TournamentPlayer.update_status(
                 tournament.id,
                 "nonexistent",
                 :checked_in
               )
    end
  end

  describe "record_match_result/3" do
    test "records win result", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.record_match_result(
                 tournament.id,
                 "player1",
                 :win
               )

      assert updated_player.wins == 1
      assert updated_player.points == 3
    end

    test "records loss result", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.record_match_result(
                 tournament.id,
                 "player1",
                 :loss
               )

      assert updated_player.losses == 1
      assert updated_player.points == 0
    end

    test "records bye result", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.record_match_result(
                 tournament.id,
                 "player1",
                 :bye
               )

      assert updated_player.byes == 1
      assert updated_player.points == 3
    end

    test "records draw result", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.record_match_result(
                 tournament.id,
                 "player1",
                 :draw
               )

      assert updated_player.points == 1
    end

    test "fails when player not found", %{tournament: tournament} do
      assert {:error, :not_found} =
               TournamentPlayer.record_match_result(
                 tournament.id,
                 "nonexistent",
                 :win
               )
    end
  end

  describe "get_player/2" do
    test "returns player when found", %{tournament: tournament} do
      {:ok, player} = TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      found_player = TournamentPlayer.get_player(tournament.id, "player1")
      assert found_player.id == player.id
    end

    test "returns nil when not found", %{tournament: tournament} do
      assert TournamentPlayer.get_player(tournament.id, "nonexistent") == nil
    end
  end

  describe "list_tournament_players/2" do
    test "lists all players in tournament", %{tournament: tournament} do
      {:ok, _player1} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      {:ok, _player2} =
        TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      players = TournamentPlayer.list_tournament_players(tournament.id)

      assert length(players) == 2
      player_ids = Enum.map(players, & &1.player_id)
      assert "player1" in player_ids
      assert "player2" in player_ids
    end

    test "filters by status", %{tournament: tournament} do
      {:ok, _player1} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      {:ok, _player2} =
        TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      # Update one player's status
      TournamentPlayer.update_status(tournament.id, "player1", :checked_in)

      players = TournamentPlayer.list_tournament_players(tournament.id, status: :checked_in)

      assert length(players) == 1
      assert hd(players).player_id == "player1"
    end

    test "orders by points", %{tournament: tournament} do
      {:ok, _player1} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      {:ok, _player2} =
        TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      # Give player2 more points
      TournamentPlayer.record_match_result(tournament.id, "player2", :win)

      players = TournamentPlayer.list_tournament_players(tournament.id, order_by: :points)

      assert length(players) == 2
      # Should be first due to higher points
      assert hd(players).player_id == "player2"
    end
  end

  describe "assign_seeds/2" do
    test "assigns random seeds", %{tournament: tournament} do
      {:ok, _} = TournamentPlayer.create_registration(tournament.id, "player1", "Player One")
      {:ok, _} = TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      assert {:ok, seeded_players} = TournamentPlayer.assign_seeds(tournament.id, :random)

      assert length(seeded_players) == 2
      seeds = Enum.map(seeded_players, & &1.seed)
      assert Enum.sort(seeds) == [1, 2]
    end

    test "assigns seeds by registration order", %{tournament: tournament} do
      {:ok, _player1} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      # Wait to ensure different timestamps
      Process.sleep(10)

      {:ok, _player2} =
        TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      assert {:ok, seeded_players} =
               TournamentPlayer.assign_seeds(tournament.id, :registration_order)

      # Should be ordered by insertion time
      assert length(seeded_players) == 2
      first_player = hd(seeded_players)
      assert first_player.player_id == "player1"
      assert first_player.seed == 1
    end

    test "assigns seeds alphabetically", %{tournament: tournament} do
      {:ok, _} = TournamentPlayer.create_registration(tournament.id, "player_zebra", "Zebra")
      {:ok, _} = TournamentPlayer.create_registration(tournament.id, "player_alpha", "Alpha")

      assert {:ok, seeded_players} = TournamentPlayer.assign_seeds(tournament.id, :alphabetical)

      # Should be ordered alphabetically
      assert length(seeded_players) == 2
      first_player = hd(seeded_players)
      assert first_player.player_name == "Alpha"
      assert first_player.seed == 1
    end
  end

  describe "withdraw_player/3" do
    test "withdraws player successfully", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} = TournamentPlayer.withdraw_player(tournament.id, "player1")

      assert updated_player.status == :withdrawn
    end

    test "withdraws player with reason", %{tournament: tournament} do
      {:ok, _player} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert {:ok, updated_player} =
               TournamentPlayer.withdraw_player(
                 tournament.id,
                 "player1",
                 "Personal emergency"
               )

      assert updated_player.status == :withdrawn
      assert updated_player.metadata.withdrawal_reason == "Personal emergency"
    end

    test "fails when player not found", %{tournament: tournament} do
      assert {:error, :not_found} = TournamentPlayer.withdraw_player(tournament.id, "nonexistent")
    end
  end

  describe "tournament_full?/1" do
    test "returns false when tournament has space", %{tournament: tournament} do
      {:ok, _} = TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      assert TournamentPlayer.tournament_full?(tournament.id) == false
    end

    test "returns true when tournament is full" do
      {:ok, small_tournament} =
        Tournament.create_tournament(%{
          name: "Small Tournament",
          format: :single_elimination,
          max_players: 1,
          creator_id: "creator123"
        })

      {:ok, _} =
        TournamentPlayer.create_registration(small_tournament.id, "player1", "Player One")

      assert TournamentPlayer.tournament_full?(small_tournament.id) == true
    end

    test "returns false for non-existent tournament" do
      assert TournamentPlayer.tournament_full?(999) == false
    end
  end

  describe "get_active_players/1" do
    test "returns active players only", %{tournament: tournament} do
      {:ok, _player1} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      {:ok, _player2} =
        TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      {:ok, _player3} =
        TournamentPlayer.create_registration(tournament.id, "player3", "Player Three")

      # Eliminate one player
      TournamentPlayer.update_status(tournament.id, "player2", :eliminated)

      active_players = TournamentPlayer.get_active_players(tournament.id)

      assert length(active_players) == 2
      active_ids = Enum.map(active_players, & &1.player_id)
      assert "player1" in active_ids
      assert "player3" in active_ids
      refute "player2" in active_ids
    end
  end

  describe "eliminate_players/3" do
    test "eliminates multiple players", %{tournament: tournament} do
      {:ok, _player1} =
        TournamentPlayer.create_registration(tournament.id, "player1", "Player One")

      {:ok, _player2} =
        TournamentPlayer.create_registration(tournament.id, "player2", "Player Two")

      {:ok, _player3} =
        TournamentPlayer.create_registration(tournament.id, "player3", "Player Three")

      assert {2, _} = TournamentPlayer.eliminate_players(tournament.id, 2, ["player1", "player2"])

      # Check that players were eliminated
      updated_player1 = TournamentPlayer.get_player(tournament.id, "player1")
      updated_player2 = TournamentPlayer.get_player(tournament.id, "player2")
      updated_player3 = TournamentPlayer.get_player(tournament.id, "player3")

      assert updated_player1.status == :eliminated
      assert updated_player1.eliminated_round == 2
      assert updated_player2.status == :eliminated
      assert updated_player2.eliminated_round == 2
      # Should remain unchanged
      assert updated_player3.status == :registered
    end
  end
end
