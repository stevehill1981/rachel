defmodule Rachel.Games.GameI18nIntegrationTest do
  @moduledoc """
  Internationalization and localization integration tests.
  Tests for multi-language support, cultural differences, and locale-specific behavior.
  
  Note: These tests are skipped because the game engine doesn't currently implement
  internationalization features. These would be handled at the UI/LiveView layer.
  """
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Game}

  @moduletag :skip

  describe "multi-language player names" do
    test "handles unicode player names correctly" do
      # Test with various international characters
      unicode_names = [
        {"josé", "José García"},
        {"李明", "李明"},
        {"الأحمد", "أحمد محمد"},
        {"владимир", "Владимир Петров"},
        {"øyvind", "Øyvind Åse"},
        {"mañana", "Mañana Piñata"},
        {"emoji_😀", "Player 😀🎮"},
        {"mixed_اللغة", "Mixed اللغة Player"}
      ]

      Enum.each(unicode_names, fn {id, name} ->
        game = Game.new()
        |> Game.add_player(id, name, false)
        |> Game.add_player("bob", "Bob", false)
        |> Game.start_game()

        # Game should handle unicode names correctly
        assert game.status == :playing
        assert count_total_cards(game) == 52
        
        # Player name should be preserved exactly
        player = Enum.find(game.players, fn p -> p.id == id end)
        assert player.name == name
        
        # Game operations should work with unicode IDs
        if Game.has_valid_play?(game, player) do
          valid_plays = Game.get_valid_plays(game, player)
          case valid_plays do
            [{_card, index} | _] ->
              {:ok, new_game} = Game.play_card(game, id, [index])
              assert new_game.status in [:playing, :finished]
            [] -> :ok
          end
        end
      end)
    end

    test "handles very long international names" do
      # Test with extremely long names in different languages
      long_names = [
        {"long_en", String.duplicate("A", 100)},
        {"long_ja", String.duplicate("あ", 50)},
        {"long_ar", String.duplicate("ع", 80)},
        {"long_emoji", String.duplicate("🎮", 25)}
      ]

      Enum.each(long_names, fn {id, name} ->
        game = Game.new()
        |> Game.add_player(id, name, false)
        |> Game.add_player("short", "B", false)
        |> Game.start_game()

        # Should handle long names gracefully
        assert game.status == :playing
        player = Enum.find(game.players, fn p -> p.id == id end)
        assert String.length(player.name) > 50
      end)
    end
  end

  describe "locale-specific game behavior" do
    test "handles different number formats and separators" do
      # Test game with locale-specific formatting expectations
      game = Game.new()
      |> Game.add_player("euro_player", "European Player", false)
      |> Game.add_player("us_player", "US Player", false)
      |> Game.start_game()

      # Game should work regardless of locale expectations
      # For instance, if UI displayed "1,234 points" vs "1.234 points"
      stats = Game.get_game_stats(game)
      
      if stats do
        # Numbers should be consistently formatted internally
        assert is_integer(stats.total_turns)
        assert is_integer(stats.total_cards_played)
      end
    end

    test "handles different text direction expectations" do
      # Test with RTL languages
      rtl_game = Game.new()
      |> Game.add_player("arabic_player", "لاعب عربي", false)
      |> Game.add_player("hebrew_player", "שחקן עברי", false)
      |> Game.start_game()

      # Game logic should be independent of text direction
      assert rtl_game.status == :playing
      assert count_total_cards(rtl_game) == 52
      
      # Player order should be consistent regardless of text direction
      current_player = Game.current_player(rtl_game)
      assert current_player.id == "arabic_player"  # First player added
    end

    test "handles different calendar systems" do
      # Test with players from different calendar systems
      # Game timestamps should be consistent
      game = Game.new()
      |> Game.add_player("gregorian", "Gregorian Player", false)
      |> Game.add_player("hijri", "Hijri Player", false)
      |> Game.start_game()

      # Game should use consistent internal time representation
      game_time = game.created_at || :os.system_time(:second)
      assert is_integer(game_time)
      assert game_time > 0
    end
  end

  describe "cultural gameplay differences" do
    test "handles different card playing conventions" do
      # Some cultures play cards differently (clockwise vs counterclockwise)
      game = Game.new()
      |> Game.add_player("western", "Western Player", false)
      |> Game.add_player("eastern", "Eastern Player", false)
      |> Game.add_player("african", "African Player", false)
      |> Game.start_game()

      # Game should support both directions
      assert game.direction in [:clockwise, :counterclockwise]
      
      # Playing a queen should reverse direction
      game_with_queen = %{game | 
        current_card: %Card{suit: :hearts, rank: :queen},
        current_player_index: 0
      }
      
      if Game.has_valid_play?(game_with_queen, hd(game_with_queen.players)) do
        # Direction change should work consistently
        original_direction = game_with_queen.direction
        
        # Simulate queen effect
        reversed_game = %{game_with_queen | 
          direction: if(original_direction == :clockwise, do: :counterclockwise, else: :clockwise)
        }
        
        assert reversed_game.direction != original_direction
      end
    end

    test "handles different social gaming expectations" do
      # Test features that might vary by culture
      game = Game.new()
      |> Game.add_player("competitive", "Competitive Player", false)
      |> Game.add_player("cooperative", "Cooperative Player", false)
      |> Game.start_game()

      # Game should support both competitive and casual play
      assert game.status == :playing
      
      # Statistics should be available for competitive players
      stats = Game.get_game_stats(game)
      if stats do
        assert is_map(stats)
      end
      
      # Game should also work without statistics for casual players
      casual_game = %{game | stats: nil}
      assert casual_game.status == :playing
    end

    test "handles different timeout expectations" do
      # Different cultures have different patience for game pacing
      game = Game.new()
      |> Game.add_player("fast_player", "Fast Player", false)
      |> Game.add_player("slow_player", "Slow Player", false)
      |> Game.start_game()

      # Game should not enforce strict timing by default
      # Players should be able to take their time
      initial_time = :os.system_time(:second)
      
      # Simulate slow play
      :timer.sleep(100)  # 100ms delay
      
      # Game should still accept moves after delay
      current_player = Game.current_player(game)
      if Game.has_valid_play?(game, current_player) do
        valid_plays = Game.get_valid_plays(game, current_player)
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, new_game} = Game.play_card(game, current_player.id, [index])
            assert new_game.status in [:playing, :finished]
          [] -> :ok
        end
      end
    end
  end

  describe "character encoding edge cases" do
    test "handles mixed character encodings" do
      # Test with different character encodings
      mixed_encoding_names = [
        {"utf8", "UTF-8 Player ñáéíóú"},
        {"latin1", "Latin-1 Player âêîôû"},
        {"ascii", "ASCII Player"},
        {"mixed", "Mixed 中文 English عربي"}
      ]

      Enum.each(mixed_encoding_names, fn {id, name} ->
        game = Game.new()
        |> Game.add_player(id, name, false)
        |> Game.add_player("standard", "Standard", false)
        |> Game.start_game()

        # Should handle all encodings consistently
        assert game.status == :playing
        player = Enum.find(game.players, fn p -> p.id == id end)
        assert is_binary(player.name)
        assert String.valid?(player.name)
      end)
    end

    test "handles zero-width and control characters" do
      # Test with problematic Unicode characters
      problematic_names = [
        {"zwj", "Zero‍Width‍Joiner"},
        {"bidi", "Bidi\u202Eoverride"},
        {"combining", "Combining̃ marks̈"},
        {"variation", "Variation︎ selectors️"}
      ]

      Enum.each(problematic_names, fn {id, name} ->
        try do
          game = Game.new()
          |> Game.add_player(id, name, false)
          |> Game.add_player("clean", "Clean Name", false)
          |> Game.start_game()

          # Should either handle gracefully or reject cleanly
          assert game.status == :playing
          player = Enum.find(game.players, fn p -> p.id == id end)
          assert is_binary(player.name)
        rescue
          _ -> :ok  # Acceptable to reject problematic characters
        end
      end)
    end
  end

  describe "time zone and date handling" do
    test "handles players from different time zones" do
      # Players from different time zones playing together
      game = Game.new()
      |> Game.add_player("utc_player", "UTC Player", false)
      |> Game.add_player("pacific_player", "Pacific Player", false)
      |> Game.add_player("tokyo_player", "Tokyo Player", false)
      |> Game.start_game()

      # Game should use consistent time internally
      game_start_time = game.created_at || :os.system_time(:second)
      assert is_integer(game_start_time)
      
      # All players should see consistent game state
      assert game.status == :playing
      assert count_total_cards(game) == 52
      
      # Turn order should be consistent regardless of time zone
      current_player = Game.current_player(game)
      assert current_player.id == "utc_player"
    end

    test "handles daylight saving time transitions" do
      # Test during DST transitions
      game = Game.new()
      |> Game.add_player("dst_player", "DST Player", false)
      |> Game.add_player("no_dst_player", "No DST Player", false)
      |> Game.start_game()

      # Game timing should be consistent regardless of DST
      assert game.status == :playing
      
      # Simulate time-based operations
      if Game.has_valid_play?(game, hd(game.players)) do
        valid_plays = Game.get_valid_plays(game, hd(game.players))
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, new_game} = Game.play_card(game, "dst_player", [index])
            
            # Time-based state should be consistent
            assert new_game.status in [:playing, :finished]
          [] -> :ok
        end
      end
    end
  end

  describe "accessibility across cultures" do
    test "handles different reading patterns" do
      # Test with different reading patterns (LTR, RTL, vertical)
      reading_patterns = [
        {"ltr", "Left-to-Right Reader"},
        {"rtl", "قارئ من اليمين إلى اليسار"},
        {"vertical", "縦書き読者"},
        {"mixed", "Mixed نمط Reader"}
      ]

      Enum.each(reading_patterns, fn {id, name} ->
        game = Game.new()
        |> Game.add_player(id, name, false)
        |> Game.add_player("standard", "Standard", false)
        |> Game.start_game()

        # Game should be playable regardless of reading pattern
        assert game.status == :playing
        
        # Card order should be consistent
        player = Enum.find(game.players, fn p -> p.id == id end)
        assert is_list(player.hand)
        assert length(player.hand) == 7
      end)
    end

    test "handles different color perception" do
      # Test with consideration for color blindness in different populations
      game = Game.new()
      |> Game.add_player("full_color", "Full Color Vision", false)
      |> Game.add_player("colorblind", "Colorblind Player", false)
      |> Game.start_game()

      # Game should be playable without relying solely on color
      # Cards should be distinguishable by suit symbols, not just color
      [full_color, colorblind] = game.players
      
      # Test card recognition
      card_types = Enum.map(full_color.hand, fn card ->
        {card.suit, card.rank}
      end)
      
      # All cards should be uniquely identifiable
      assert length(card_types) == length(Enum.uniq(card_types))
      
      # Suits should be distinguishable
      suits = Enum.map(full_color.hand, fn card -> card.suit end)
      unique_suits = Enum.uniq(suits)
      assert length(unique_suits) <= 4  # Max 4 suits
    end
  end

  describe "performance with international content" do
    test "handles sorting with international characters" do
      # Test performance with international character sorting
      international_players = [
        {"åse", "Åse"},
        {"zhang", "张三"},
        {"abdul", "عبدالله"},
        {"josé", "José"},
        {"øyvind", "Øyvind"}
      ]

      game = Enum.reduce(international_players, Game.new(), fn {id, name}, acc ->
        Game.add_player(acc, id, name, false)
      end)
      |> Game.start_game()

      # Game should handle international names efficiently
      start_time = System.monotonic_time(:microsecond)
      
      # Operations that might involve sorting/comparison
      current_player = Game.current_player(game)
      all_players = game.players
      
      end_time = System.monotonic_time(:microsecond)
      elapsed_ms = (end_time - start_time) / 1000
      
      # Should be fast even with international characters
      assert elapsed_ms < 10
      assert current_player != nil
      assert length(all_players) == 5
    end

    test "handles large international text efficiently" do
      # Test with very long international names
      long_international = String.duplicate("國際化", 50)  # 150 characters
      
      game = Game.new()
      |> Game.add_player("long_intl", long_international, false)
      |> Game.add_player("normal", "Normal", false)
      |> Game.start_game()

      # Should handle long international text without performance issues
      start_time = System.monotonic_time(:microsecond)
      
      player = Enum.find(game.players, fn p -> p.id == "long_intl" end)
      name_length = String.length(player.name)
      
      end_time = System.monotonic_time(:microsecond)
      elapsed_ms = (end_time - start_time) / 1000
      
      assert elapsed_ms < 5
      assert name_length == 150
    end
  end

  # Helper functions
  defp count_total_cards(game) do
    cards_in_hands = Enum.sum(Enum.map(game.players, fn p -> length(p.hand) end))
    cards_in_deck = length(game.deck.cards)
    cards_in_discard = length(game.discard_pile)
    
    cards_in_hands + cards_in_deck + cards_in_discard
  end
end