defmodule Rachel.Games.StatsTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Stats}

  describe "new/1" do
    test "creates stats for all players" do
      player_ids = ["p1", "p2", "p3"]
      stats = Stats.new(player_ids)

      assert not is_nil(stats.start_time)
      assert not is_nil(stats.player_stats["p1"])
      assert not is_nil(stats.player_stats["p2"])
      assert not is_nil(stats.player_stats["p3"])

      # Each player starts with zero stats
      Enum.each(player_ids, fn id ->
        player_stat = stats.player_stats[id]
        assert player_stat.total_cards_played == 0
        assert player_stat.total_cards_drawn == 0
        assert player_stat.special_cards_played == 0
        assert player_stat.games_played == 1
      end)
    end
  end

  describe "record_card_played/3" do
    setup do
      stats = Stats.new(["p1", "p2"])
      {:ok, stats: stats}
    end

    test "records single card played", %{stats: stats} do
      card = Card.new(:hearts, 3)
      new_stats = Stats.record_card_played(stats, "p1", [card])

      assert new_stats.player_stats["p1"].total_cards_played == 1
      assert new_stats.game_stats.total_cards_played == 1
    end

    test "records multiple cards played", %{stats: stats} do
      cards = [
        Card.new(:hearts, 3),
        Card.new(:spades, 3),
        Card.new(:clubs, 3)
      ]

      new_stats = Stats.record_card_played(stats, "p1", cards)

      assert new_stats.player_stats["p1"].total_cards_played == 3
      assert new_stats.game_stats.total_cards_played == 3
    end

    test "records special cards", %{stats: stats} do
      # 2s are special (pickup)
      cards = [Card.new(:hearts, 2)]
      new_stats = Stats.record_card_played(stats, "p1", cards)

      assert new_stats.player_stats["p1"].special_cards_played == 1
      assert new_stats.game_stats.special_effects_triggered == 1
    end

    test "records multiple special cards", %{stats: stats} do
      cards = [
        # Pickup 2
        Card.new(:hearts, 2),
        # Skip
        Card.new(:spades, 7),
        # Reverse
        Card.new(:hearts, :queen),
        # Black jack
        Card.new(:spades, :jack),
        # Choose suit
        Card.new(:hearts, :ace)
      ]

      new_stats = Stats.record_card_played(stats, "p1", cards)

      assert new_stats.player_stats["p1"].special_cards_played == 5
      assert new_stats.game_stats.special_effects_triggered == 5
    end

    test "ignores unknown player", %{stats: stats} do
      card = Card.new(:hearts, 3)
      new_stats = Stats.record_card_played(stats, "unknown", [card])

      # Should return unchanged stats
      assert new_stats == stats
    end
  end

  describe "record_card_drawn/3" do
    setup do
      stats = Stats.new(["p1", "p2"])
      {:ok, stats: stats}
    end

    test "records cards drawn", %{stats: stats} do
      new_stats = Stats.record_card_drawn(stats, "p1", 1)

      assert new_stats.player_stats["p1"].total_cards_drawn == 1
      assert new_stats.game_stats.total_cards_drawn == 1
    end

    test "records multiple cards drawn", %{stats: stats} do
      new_stats = Stats.record_card_drawn(stats, "p1", 5)

      assert new_stats.player_stats["p1"].total_cards_drawn == 5
      assert new_stats.game_stats.total_cards_drawn == 5
    end

    test "accumulates draws", %{stats: stats} do
      new_stats =
        stats
        |> Stats.record_card_drawn("p1", 2)
        |> Stats.record_card_drawn("p1", 3)
        |> Stats.record_card_drawn("p2", 1)

      assert new_stats.player_stats["p1"].total_cards_drawn == 5
      assert new_stats.player_stats["p2"].total_cards_drawn == 1
      assert new_stats.game_stats.total_cards_drawn == 6
    end
  end

  describe "record_turn_advance/1" do
    test "increments turn counters" do
      stats = Stats.new(["p1", "p2"])

      new_stats =
        stats
        |> Stats.record_turn_advance()
        |> Stats.record_turn_advance()
        |> Stats.record_turn_advance()

      assert new_stats.game_stats.total_turns == 3
    end
  end

  describe "record_direction_change/1" do
    test "counts direction changes" do
      stats = Stats.new(["p1", "p2"])

      new_stats =
        stats
        |> Stats.record_direction_change()
        |> Stats.record_direction_change()

      assert new_stats.game_stats.direction_changes == 2
    end
  end

  describe "record_suit_nomination/1" do
    test "counts suit nominations" do
      stats = Stats.new(["p1", "p2"])

      new_stats = Stats.record_suit_nomination(stats)

      assert new_stats.game_stats.suit_nominations == 1
    end
  end

  describe "record_winner/2" do
    setup do
      stats = Stats.new(["p1", "p2", "p3"])
      {:ok, stats: stats}
    end

    test "records first winner", %{stats: stats} do
      new_stats = Stats.record_winner(stats, "p2")

      assert new_stats.game_stats.winner_id == "p2"
      assert new_stats.game_stats.finish_positions == ["p2"]
      assert new_stats.player_stats["p2"].position == 1
    end

    test "records multiple winners in order", %{stats: stats} do
      new_stats =
        stats
        |> Stats.record_winner("p2")
        |> Stats.record_winner("p3")
        |> Stats.record_winner("p1")

      assert new_stats.game_stats.finish_positions == ["p2", "p3", "p1"]
      assert new_stats.player_stats["p2"].position == 1
      assert new_stats.player_stats["p3"].position == 2
      assert new_stats.player_stats["p1"].position == 3
    end

    test "calculates game duration on first winner", %{stats: stats} do
      # Simulate some time passing
      Process.sleep(100)

      new_stats = Stats.record_winner(stats, "p1")

      assert new_stats.game_stats.game_duration_seconds != nil
      assert new_stats.game_stats.game_duration_seconds >= 0
    end
  end

  describe "format_stats/1" do
    test "formats complete game stats" do
      stats =
        Stats.new(["p1", "p2"])
        |> Stats.record_card_played("p1", [Card.new(:hearts, 2)])
        |> Stats.record_card_drawn("p2", 2)
        |> Stats.record_turn_advance()
        |> Stats.record_direction_change()
        |> Stats.record_suit_nomination()
        |> Stats.record_winner("p1")
        |> Stats.record_winner("p2")

      formatted = Stats.format_stats(stats)

      assert formatted.game.total_turns == 1
      assert formatted.game.total_cards_played == 1
      # First winner
      assert formatted.game.winner == "p1"
      assert formatted.game.duration_minutes =~ ~r/\d+[ms]/

      assert length(formatted.players) == 2

      # Find players by id since order is by score
      p1_stats = Enum.find(formatted.players, &(&1.id == "p1"))
      p2_stats = Enum.find(formatted.players, &(&1.id == "p2"))

      assert p1_stats.cards_played == 1
      assert p1_stats.cards_drawn == 0
      # First place
      assert p1_stats.won == true

      assert p2_stats.cards_played == 0
      assert p2_stats.cards_drawn == 2
      # Second place doesn't count as won
      assert p2_stats.won == false
    end

    test "handles incomplete game" do
      stats =
        Stats.new(["p1", "p2"])
        |> Stats.record_card_played("p1", [Card.new(:hearts, 3)])

      formatted = Stats.format_stats(stats)

      assert formatted.game.winner == nil
      assert formatted.game.duration_minutes == "In progress"
      # Still shows players with scores
      assert length(formatted.players) == 2
    end
  end

  describe "special card detection" do
    test "identifies all special cards correctly" do
      stats = Stats.new(["p1"])

      # Test each special card type
      special_cards = [
        # Pickup 2
        Card.new(:hearts, 2),
        # Skip
        Card.new(:spades, 7),
        # Reverse (queens reverse, not 8s)
        Card.new(:hearts, :queen),
        # Black jack
        Card.new(:spades, :jack),
        # Choose suit
        Card.new(:hearts, :ace)
      ]

      new_stats = Stats.record_card_played(stats, "p1", special_cards)

      assert new_stats.player_stats["p1"].special_cards_played == 5
      assert new_stats.game_stats.special_effects_triggered == 5
    end

    test "normal cards don't count as special" do
      stats = Stats.new(["p1"])

      normal_cards = [
        Card.new(:hearts, 3),
        # 8s are NOT special
        Card.new(:spades, 8),
        Card.new(:hearts, :king),
        Card.new(:diamonds, 10)
      ]

      new_stats = Stats.record_card_played(stats, "p1", normal_cards)

      assert new_stats.player_stats["p1"].special_cards_played == 0
      assert new_stats.game_stats.special_effects_triggered == 0
    end
  end
end
