defmodule Rachel.Games.CommentaryTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.Commentary

  describe "generate_comment/2 for :play events" do
    test "generates comment for single card play without special effects" do
      card = %{rank: :ace, suit: :hearts}
      params = %{
        player: %{name: "Alice"},
        cards: [card],
        special_effects: []
      }

      result = Commentary.generate_comment(:play, params)
      assert result == "Alice plays Ace of Hearts ♥."
    end

    test "generates comment for single card play with special effects" do
      card = %{rank: 7, suit: :clubs}
      params = %{
        player: %{name: "Bob"},
        cards: [card],
        special_effects: [{:skip, 1}]
      }

      result = Commentary.generate_comment(:play, params)
      assert result == "Bob plays 7 of Clubs ♣ - skip 1!"
    end

    test "generates comment for multiple cards play" do
      cards = [%{rank: 5, suit: :hearts}, %{rank: 5, suit: :diamonds}]
      params = %{
        player: %{name: "Charlie"},
        cards: cards,
        special_effects: []
      }

      result = Commentary.generate_comment(:play, params)
      assert result == "Charlie plays 2 5s."
    end

    test "generates comment for multiple cards with special effects" do
      cards = [%{rank: 2, suit: :spades}, %{rank: 2, suit: :clubs}]
      params = %{
        player: %{name: "Dana"},
        cards: cards,
        special_effects: [{:pickup, 4}, {:skip, 1}]
      }

      result = Commentary.generate_comment(:play, params)
      assert result == "Dana plays 2 2s - +4 cards, skip 1!"
    end

    test "handles all face card ranks" do
      face_cards = [
        {%{rank: :king, suit: :hearts}, "King of Hearts ♥"},
        {%{rank: :queen, suit: :diamonds}, "Queen of Diamonds ♦"},
        {%{rank: :jack, suit: :clubs}, "Jack of Clubs ♣"},
        {%{rank: :ace, suit: :spades}, "Ace of Spades ♠"}
      ]

      Enum.each(face_cards, fn {card, expected_card_text} ->
        params = %{
          player: %{name: "Player"},
          cards: [card],
          special_effects: []
        }

        result = Commentary.generate_comment(:play, params)
        assert result == "Player plays #{expected_card_text}."
      end)
    end

    test "handles all number ranks" do
      for rank <- 2..10 do
        card = %{rank: rank, suit: :hearts}
        params = %{
          player: %{name: "Player"},
          cards: [card],
          special_effects: []
        }

        result = Commentary.generate_comment(:play, params)
        assert result == "Player plays #{rank} of Hearts ♥."
      end
    end

    test "handles all suits" do
      suits = [:hearts, :diamonds, :clubs, :spades]
      expected_suffixes = ["♥", "♦", "♣", "♠"]

      Enum.zip(suits, expected_suffixes)
      |> Enum.each(fn {suit, expected_suffix} ->
        card = %{rank: :ace, suit: suit}
        params = %{
          player: %{name: "Player"},
          cards: [card],
          special_effects: []
        }

        result = Commentary.generate_comment(:play, params)
        assert String.ends_with?(result, "#{expected_suffix}.")
      end)
    end

    test "handles multiple special effects" do
      card = %{rank: :jack, suit: :spades}
      params = %{
        player: %{name: "Eve"},
        cards: [card],
        special_effects: [{:pickup, 5}, :reverse, {:nominate, :hearts}]
      }

      result = Commentary.generate_comment(:play, params)
      assert result == "Eve plays Jack of Spades ♠ - +5 cards, reverse direction, nominate Hearts ♥!"
    end
  end

  describe "generate_comment/2 for :draw events" do
    test "generates comment for forced draw" do
      params = %{
        player: %{name: "Alice"},
        count: 2,
        reason: :forced
      }

      result = Commentary.generate_comment(:draw, params)
      assert result == "Alice is forced to draw 2 cards."
    end

    test "generates comment for no valid play draw" do
      params = %{
        player: %{name: "Bob"},
        count: 1,
        reason: :no_valid_play
      }

      result = Commentary.generate_comment(:draw, params)
      assert result == "Bob has no valid plays and draws 1 card."
    end

    test "generates comment for choice draw" do
      params = %{
        player: %{name: "Charlie"},
        count: 3,
        reason: :choice
      }

      result = Commentary.generate_comment(:draw, params)
      assert result == "Charlie chooses to draw 3 cards."
    end

    test "uses singular form for single card" do
      params = %{
        player: %{name: "Dana"},
        count: 1,
        reason: :forced
      }

      result = Commentary.generate_comment(:draw, params)
      assert result == "Dana is forced to draw 1 card."
    end

    test "uses plural form for multiple cards" do
      params = %{
        player: %{name: "Eve"},
        count: 5,
        reason: :choice
      }

      result = Commentary.generate_comment(:draw, params)
      assert result == "Eve chooses to draw 5 cards."
    end
  end

  describe "generate_comment/2 for :skip events" do
    test "generates comment for single turn skip" do
      params = %{
        player: %{name: "Alice"},
        count: 1
      }

      result = Commentary.generate_comment(:skip, params)
      assert result == "Alice is skipped for 1 turn!"
    end

    test "generates comment for multiple turns skip" do
      params = %{
        player: %{name: "Bob"},
        count: 3
      }

      result = Commentary.generate_comment(:skip, params)
      assert result == "Bob is skipped for 3 turns!"
    end
  end

  describe "generate_comment/2 for :reverse events" do
    test "generates comment for clockwise direction" do
      params = %{direction: :clockwise}

      result = Commentary.generate_comment(:reverse, params)
      assert result == "Play direction reverses to clockwise!"
    end

    test "generates comment for counter-clockwise direction" do
      params = %{direction: :counter_clockwise}

      result = Commentary.generate_comment(:reverse, params)
      assert result == "Play direction reverses to counter-clockwise!"
    end
  end

  describe "generate_comment/2 for :effect events" do
    test "generates comment for suit nomination" do
      params = %{
        effect: :suit_nomination,
        details: %{player: "Alice", suit: :hearts}
      }

      result = Commentary.generate_comment(:effect, params)
      assert result == "Alice nominates Hearts ♥ suit!"
    end

    test "generates comment for pickup stack" do
      params = %{
        effect: :pickup_stack,
        details: %{count: 4}
      }

      result = Commentary.generate_comment(:effect, params)
      assert result == "4 pickup cards are stacked - next player must draw or counter!"
    end

    test "generates comment for skip stack" do
      params = %{
        effect: :skip_stack,
        details: %{count: 2}
      }

      result = Commentary.generate_comment(:effect, params)
      assert result == "2 skip effects are stacked!"
    end

    test "generates comment for counter play" do
      params = %{
        effect: :counter_play,
        details: %{
          player: "Bob",
          card: %{rank: :jack, suit: :hearts}
        }
      }

      result = Commentary.generate_comment(:effect, params)
      assert result == "Bob counters with a Jack of Hearts ♥!"
    end
  end

  describe "generate_comment/2 for :win events" do
    test "generates comment for first place winner" do
      params = %{
        player: %{name: "Alice"},
        position: 1,
        total_players: 4
      }

      result = Commentary.generate_comment(:win, params)
      assert result == "🎉 Alice wins the game! Excellent strategy!"
    end

    test "generates comment for second place" do
      params = %{
        player: %{name: "Bob"},
        position: 2,
        total_players: 4
      }

      result = Commentary.generate_comment(:win, params)
      assert result == "Bob finishes in 2nd place - well played!"
    end

    test "generates comment for last place" do
      params = %{
        player: %{name: "Charlie"},
        position: 4,
        total_players: 4
      }

      result = Commentary.generate_comment(:win, params)
      assert result == "Charlie finishes last, but every game is a learning experience!"
    end

    test "generates comment for middle positions" do
      params = %{
        player: %{name: "Dana"},
        position: 3,
        total_players: 5
      }

      result = Commentary.generate_comment(:win, params)
      assert result == "Dana finishes in position 3."
    end
  end

  describe "generate_comment/2 for :join events" do
    test "generates comment for spectator join" do
      params = %{
        player: %{name: "Alice"},
        type: :spectator
      }

      result = Commentary.generate_comment(:join, params)
      assert result == "👀 Alice joins as a spectator."
    end

    test "generates comment for player join" do
      params = %{
        player: %{name: "Bob"},
        type: :player
      }

      result = Commentary.generate_comment(:join, params)
      assert result == "🎮 Bob joins the game!"
    end
  end

  describe "generate_comment/2 for :disconnect events" do
    test "generates comment for player disconnect" do
      params = %{
        player: %{name: "Alice"}
      }

      result = Commentary.generate_comment(:disconnect, params)
      assert result == "📵 Alice has disconnected."
    end
  end

  describe "generate_strategic_comment/1" do
    test "returns low card warning when player has 2 cards" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      result = Commentary.generate_strategic_comment(game)
      assert result == "⚠️ Alice is down to 2 cards!"
    end

    test "returns low card warning when player has 1 card" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      result = Commentary.generate_strategic_comment(game)
      assert result == "⚠️ Alice is down to 1 cards!"
    end

    test "returns high pickup stack warning" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 6,
        pending_skips: 0
      }

      result = Commentary.generate_strategic_comment(game)
      assert result == "💀 6 pickup cards stacked - this could be devastating!"
    end

    test "returns close game warning when multiple players have 3 or fewer cards" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}]},      # 3 cards
          %{name: "Bob", hand: [%{}, %{}, %{}]},        # 3 cards
          %{name: "Charlie", hand: [%{}, %{}, %{}, %{}, %{}]}  # 5 cards
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      result = Commentary.generate_strategic_comment(game)
      assert result == "🔥 This game is heating up - multiple players close to winning!"
    end

    test "returns AI strategic play comment when randomly triggered" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      # Since ai_strategic_play is random, test multiple times
      results = for _ <- 1..50 do
        Commentary.generate_strategic_comment(game)
      end

      # Should sometimes return the AI comment
      ai_comments = Enum.filter(results, &(&1 == "🤖 Smart play by the AI - that move could change everything!"))
      assert length(ai_comments) > 0
    end

    test "returns nil when no strategic conditions are met" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      # Run multiple times to account for random AI strategic play
      results = for _ <- 1..10 do
        Commentary.generate_strategic_comment(game)
      end

      # Should have at least some nil results
      nil_results = Enum.filter(results, &is_nil/1)
      assert length(nil_results) > 0
    end

    test "ignores players with 0 cards for low card warning" do
      game = %{
        players: [
          %{name: "Alice", hand: []},  # 0 cards - should be ignored
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      # Should not trigger low card warning for player with 0 cards
      # Run multiple times to account for random AI strategic play
      results = for _ <- 1..10 do
        Commentary.generate_strategic_comment(game)
      end

      low_card_warnings = Enum.filter(results, &(&1 && String.contains?(&1, "down to")))
      assert length(low_card_warnings) == 0
    end
  end

  describe "get_excitement_level/1" do
    test "returns :low for calm game state" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0,
        direction: :clockwise
      }

      result = Commentary.get_excitement_level(game)
      assert result == :low
    end

    test "returns :medium for moderate excitement with pickup stack" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 6,  # +2 points
        pending_skips: 0,
        direction: :clockwise
      }

      result = Commentary.get_excitement_level(game)
      assert result == :medium
    end

    test "returns :high for high excitement with close game" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}]},  # 3 cards
          %{name: "Bob", hand: [%{}, %{}, %{}]},    # 3 cards (close_game +3)
          %{name: "Charlie", hand: [%{}, %{}, %{}, %{}, %{}]}  # 5 cards
        ],
        pending_pickups: 0,
        pending_skips: 0,
        direction: :counter_clockwise  # +1 point
      }

      result = Commentary.get_excitement_level(game)
      assert result == :high  # 3 + 1 = 4 points
    end

    test "returns :extreme for very high excitement" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}]},  # 2 cards
          %{name: "Bob", hand: [%{}, %{}]}     # 2 cards (multiple_low_cards +2, close_game +3)
        ],
        pending_pickups: 6,         # +2 points
        pending_skips: 3,           # +1 point
        direction: :counter_clockwise  # +1 point
      }

      result = Commentary.get_excitement_level(game)
      assert result == :extreme  # 2 + 3 + 2 + 1 + 1 = 9 points
    end

    test "factors in high pickup stack only" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 6,  # +2 points
        pending_skips: 0,
        direction: :clockwise
      }

      result = Commentary.get_excitement_level(game)
      assert result == :medium  # 2 points
    end

    test "factors in skip stack only" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 3,    # +1 point
        direction: :clockwise
      }

      result = Commentary.get_excitement_level(game)
      assert result == :low  # 1 point
    end

    test "factors in counter-clockwise direction only" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0,
        direction: :counter_clockwise  # +1 point
      }

      result = Commentary.get_excitement_level(game)
      assert result == :low  # 1 point
    end

    test "correctly calculates excitement score boundaries" do
      # Test boundary between :low and :medium (score 2)
      game_medium = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 6,  # +2 points = 2 total
        pending_skips: 0,
        direction: :clockwise
      }

      assert Commentary.get_excitement_level(game_medium) == :medium

      # Test boundary between :medium and :high (score 4)
      game_high = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}]},      # 3 cards
          %{name: "Bob", hand: [%{}, %{}, %{}]},        # 3 cards (close_game +3)
          %{name: "Charlie", hand: [%{}, %{}, %{}, %{}, %{}]}  # 5 cards
        ],
        pending_pickups: 0,
        pending_skips: 0,
        direction: :counter_clockwise  # +1 point = 4 total
      }

      assert Commentary.get_excitement_level(game_high) == :high

      # Test boundary between :high and :extreme (score 6+)
      game_extreme = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}]},  # 2 cards
          %{name: "Bob", hand: [%{}, %{}]}     # 2 cards (multiple_low_cards +2, close_game +3)
        ],
        pending_pickups: 6,         # +2 points
        pending_skips: 0,
        direction: :counter_clockwise  # +1 point = 8 total
      }

      assert Commentary.get_excitement_level(game_extreme) == :extreme
    end
  end

  describe "private helper functions" do
    test "format_special_effect handles all effect types" do
      # These are private functions, but we can test them indirectly through generate_comment
      card = %{rank: :ace, suit: :hearts}
      
      test_effects = [
        {[{:pickup, 3}], "+3 cards"},
        {[{:skip, 2}], "skip 2"},
        {[:reverse], "reverse direction"},
        {[{:nominate, :spades}], "nominate Spades ♠"}
      ]

      Enum.each(test_effects, fn {effects, expected_text} ->
        params = %{
          player: %{name: "Player"},
          cards: [card],
          special_effects: effects
        }

        result = Commentary.generate_comment(:play, params)
        assert String.contains?(result, expected_text)
      end)
    end

    test "format_cards_played handles single vs multiple cards correctly" do
      # Test through generate_comment
      single_card_params = %{
        player: %{name: "Alice"},
        cards: [%{rank: :king, suit: :hearts}],
        special_effects: []
      }

      multiple_cards_params = %{
        player: %{name: "Bob"},
        cards: [%{rank: 5, suit: :hearts}, %{rank: 5, suit: :diamonds}, %{rank: 5, suit: :clubs}],
        special_effects: []
      }

      single_result = Commentary.generate_comment(:play, single_card_params)
      multiple_result = Commentary.generate_comment(:play, multiple_cards_params)

      assert single_result == "Alice plays King of Hearts ♥."
      assert multiple_result == "Bob plays 3 5s."
    end
  end

  describe "edge cases and error handling" do
    test "handles empty special effects list" do
      params = %{
        player: %{name: "Alice"},
        cards: [%{rank: :ace, suit: :hearts}],
        special_effects: []
      }

      result = Commentary.generate_comment(:play, params)
      assert result == "Alice plays Ace of Hearts ♥."
    end

    test "handles zero count for draw" do
      params = %{
        player: %{name: "Alice"},
        count: 0,
        reason: :choice
      }

      result = Commentary.generate_comment(:draw, params)
      assert result == "Alice chooses to draw 0 cards."
    end

    test "handles zero count for skip" do
      params = %{
        player: %{name: "Alice"},
        count: 0
      }

      result = Commentary.generate_comment(:skip, params)
      assert result == "Alice is skipped for 0 turns!"
    end

    test "handles players with empty hands in strategic comments" do
      game = %{
        players: [
          %{name: "Alice", hand: []},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 0,
        pending_skips: 0
      }

      # Should not crash and should not return low card warning for empty hand
      result = Commentary.generate_strategic_comment(game)
      # Result can be nil or AI strategic play comment, but not low card warning
      assert result == nil or String.contains?(result, "AI")
    end

    test "handles large numbers in pickup and skip stacks" do
      game = %{
        players: [
          %{name: "Alice", hand: [%{}, %{}, %{}, %{}, %{}]},
          %{name: "Bob", hand: [%{}, %{}, %{}, %{}, %{}]}
        ],
        pending_pickups: 50,  # +2 points (>5)
        pending_skips: 20,    # +1 point (>2)
        direction: :clockwise # +0 points
      }

      result = Commentary.get_excitement_level(game)
      assert result == :medium  # 2 + 1 + 0 + 0 + 0 = 3 points
    end
  end
end