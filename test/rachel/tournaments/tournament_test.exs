defmodule Rachel.Tournaments.TournamentTest do
  use Rachel.DataCase, async: true

  alias Rachel.Tournaments.{Tournament, TournamentMatch}

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Tournament.changeset(%Tournament{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).format
      assert "can't be blank" in errors_on(changeset).max_players
      assert "can't be blank" in errors_on(changeset).creator_id
    end

    test "validates name length" do
      attrs = valid_tournament_attrs()

      # Too short
      changeset = Tournament.changeset(%Tournament{}, %{attrs | name: "ab"})
      assert "should be at least 3 character(s)" in errors_on(changeset).name

      # Too long
      long_name = String.duplicate("a", 101)
      changeset = Tournament.changeset(%Tournament{}, %{attrs | name: long_name})
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end

    test "validates max_players range" do
      attrs = valid_tournament_attrs()

      # Too low
      changeset = Tournament.changeset(%Tournament{}, %{attrs | max_players: 1})
      assert "must be greater than 1" in errors_on(changeset).max_players

      # Too high
      changeset = Tournament.changeset(%Tournament{}, %{attrs | max_players: 65})
      assert "must be less than or equal to 64" in errors_on(changeset).max_players
    end

    test "validates entry_fee is non-negative" do
      attrs = valid_tournament_attrs()

      changeset = Tournament.changeset(%Tournament{}, %{attrs | entry_fee: -1})
      assert "must be greater than or equal to 0" in errors_on(changeset).entry_fee
    end

    test "calculates total_rounds for single elimination" do
      attrs = %{valid_tournament_attrs() | format: :single_elimination, max_players: 8}

      changeset = Tournament.changeset(%Tournament{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :total_rounds) == 3
    end

    test "calculates total_rounds for double elimination" do
      attrs = %{valid_tournament_attrs() | format: :double_elimination, max_players: 8}

      changeset = Tournament.changeset(%Tournament{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :total_rounds) == 5
    end

    test "calculates total_rounds for round robin" do
      attrs = %{valid_tournament_attrs() | format: :round_robin, max_players: 6}

      changeset = Tournament.changeset(%Tournament{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :total_rounds) == 5
    end

    test "calculates total_rounds for swiss" do
      attrs = %{valid_tournament_attrs() | format: :swiss, max_players: 16}

      changeset = Tournament.changeset(%Tournament{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :total_rounds) == 5
    end
  end

  describe "create_tournament/1" do
    test "creates tournament with valid attrs" do
      attrs = valid_tournament_attrs()

      assert {:ok, tournament} = Tournament.create_tournament(attrs)
      assert tournament.name == attrs.name
      assert tournament.format == attrs.format
      assert tournament.max_players == attrs.max_players
      assert tournament.creator_id == attrs.creator_id
      assert tournament.status == :registration
    end

    test "fails with invalid attrs" do
      assert {:error, changeset} = Tournament.create_tournament(%{})
      refute changeset.valid?
    end
  end

  describe "get_tournament_full/1" do
    test "returns tournament with associations" do
      tournament = insert_tournament()

      result = Tournament.get_tournament_full(tournament.id)
      assert result.id == tournament.id
      assert Ecto.assoc_loaded?(result.tournament_players)
      assert Ecto.assoc_loaded?(result.matches)
    end

    test "returns nil for non-existent tournament" do
      assert Tournament.get_tournament_full(999) == nil
    end
  end

  describe "list_tournaments/1" do
    test "lists tournaments with default options" do
      tournament1 = insert_tournament()
      tournament2 = insert_tournament()

      tournaments = Tournament.list_tournaments()

      assert length(tournaments) == 2
      tournament_ids = Enum.map(tournaments, & &1.id)
      assert tournament1.id in tournament_ids
      assert tournament2.id in tournament_ids
    end

    test "filters by status" do
      tournament1 = insert_tournament(%{status: :registration})
      _tournament2 = insert_tournament(%{status: :completed})

      tournaments = Tournament.list_tournaments(status: :registration)

      assert length(tournaments) == 1
      assert hd(tournaments).id == tournament1.id
    end

    test "filters by format" do
      tournament1 = insert_tournament(%{format: :single_elimination})
      _tournament2 = insert_tournament(%{format: :round_robin})

      tournaments = Tournament.list_tournaments(format: :single_elimination)

      assert length(tournaments) == 1
      assert hd(tournaments).id == tournament1.id
    end

    test "respects limit" do
      insert_tournament()
      insert_tournament()
      insert_tournament()

      tournaments = Tournament.list_tournaments(limit: 2)

      assert length(tournaments) == 2
    end

    test "filters public tournaments only" do
      tournament1 = insert_tournament(%{is_public: true})
      _tournament2 = insert_tournament(%{is_public: false})

      tournaments = Tournament.list_tournaments(public_only: true)

      assert length(tournaments) == 1
      assert hd(tournaments).id == tournament1.id
    end
  end

  describe "register_player/3" do
    test "registers player successfully" do
      tournament = insert_tournament()

      assert {:ok, player} = Tournament.register_player(tournament.id, "player1", "Player One")
      assert player.tournament_id == tournament.id
      assert player.player_id == "player1"
      assert player.player_name == "Player One"
      assert player.status == :registered
    end

    test "fails when tournament not found" do
      assert {:error, :not_found} = Tournament.register_player(999, "player1", "Player One")
    end

    test "fails when tournament not in registration status" do
      tournament = insert_tournament(%{status: :in_progress})

      assert {:error, :registration_closed} =
               Tournament.register_player(tournament.id, "player1", "Player One")
    end

    test "fails when player already registered" do
      tournament = insert_tournament()
      {:ok, _} = Tournament.register_player(tournament.id, "player1", "Player One")

      assert {:error, :already_registered} =
               Tournament.register_player(tournament.id, "player1", "Player One")
    end

    test "fails when tournament is full" do
      tournament = insert_tournament(%{max_players: 2})
      {:ok, _} = Tournament.register_player(tournament.id, "player1", "Player One")
      {:ok, _} = Tournament.register_player(tournament.id, "player2", "Player Two")

      assert {:error, :tournament_full} =
               Tournament.register_player(tournament.id, "player3", "Player Three")
    end
  end

  describe "start_tournament/2" do
    test "starts tournament successfully" do
      tournament = insert_tournament()
      # Register minimum players
      {:ok, _} = Tournament.register_player(tournament.id, "player1", "Player One")
      {:ok, _} = Tournament.register_player(tournament.id, "player2", "Player Two")

      assert {:ok, updated_tournament} =
               Tournament.start_tournament(tournament.id, tournament.creator_id)

      assert updated_tournament.status == :in_progress
      assert updated_tournament.current_round == 1
      assert updated_tournament.start_time != nil
    end

    test "fails when tournament not found" do
      assert {:error, :not_found} = Tournament.start_tournament(999, "creator")
    end

    test "fails when not authorized" do
      tournament = insert_tournament()

      assert {:error, :not_authorized} =
               Tournament.start_tournament(tournament.id, "different_creator")
    end

    test "fails when tournament not in registration status" do
      tournament = insert_tournament(%{status: :in_progress})

      assert {:error, :cannot_start} =
               Tournament.start_tournament(tournament.id, tournament.creator_id)
    end

    test "fails when not enough players" do
      tournament = insert_tournament()
      # Only register one player, but need minimum 2
      {:ok, _} = Tournament.register_player(tournament.id, "player1", "Player One")

      assert {:error, :not_enough_players} =
               Tournament.start_tournament(tournament.id, tournament.creator_id)
    end
  end

  describe "get_leaderboard/1" do
    test "returns leaderboard for existing tournament" do
      tournament = insert_tournament()

      assert {:ok, leaderboard} = Tournament.get_leaderboard(tournament.id)
      assert is_list(leaderboard)
    end

    test "returns error for non-existent tournament" do
      assert {:error, :not_found} = Tournament.get_leaderboard(999)
    end
  end

  describe "advance_tournament/1" do
    test "completes tournament when all rounds finished" do
      tournament =
        insert_tournament(%{
          status: :in_progress,
          current_round: 3,
          total_rounds: 3
        })

      # Create completed final match
      {:ok, _match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 3,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          winner_id: "player1",
          status: :completed
        })

      assert {:ok, updated_tournament} = Tournament.advance_tournament(tournament.id)
      assert updated_tournament.status == :completed
      assert updated_tournament.end_time != nil
    end

    test "fails when tournament not found" do
      assert {:error, :not_found} = Tournament.advance_tournament(999)
    end

    test "fails when tournament not in progress" do
      tournament = insert_tournament(%{status: :registration})

      assert {:error, :tournament_not_in_progress} = Tournament.advance_tournament(tournament.id)
    end

    test "fails when round not complete" do
      tournament =
        insert_tournament(%{
          status: :in_progress,
          current_round: 1,
          total_rounds: 3
        })

      # Create incomplete match
      {:ok, _match} =
        TournamentMatch.create_match(%{
          tournament_id: tournament.id,
          round: 1,
          match_number: 1,
          player1_id: "player1",
          player2_id: "player2",
          status: :pending
        })

      assert {:error, :round_not_complete} = Tournament.advance_tournament(tournament.id)
    end
  end

  # Helper functions

  defp valid_tournament_attrs do
    %{
      name: "Test Tournament",
      description: "A test tournament",
      format: :single_elimination,
      max_players: 8,
      creator_id: "creator123",
      entry_fee: 0,
      prize_pool: 100,
      is_public: true
    }
  end

  defp insert_tournament(attrs \\ %{}) do
    attrs = Map.merge(valid_tournament_attrs(), attrs)
    {:ok, tournament} = Tournament.create_tournament(attrs)
    tournament
  end
end
