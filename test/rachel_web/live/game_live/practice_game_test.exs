defmodule RachelWeb.GameLive.PracticeGameTest do
  @moduledoc """
  Tests for the PracticeGame module.
  """

  use ExUnit.Case, async: true

  alias Rachel.Games.Game
  alias RachelWeb.GameLive.PracticeGame

  describe "create_test_game/1" do
    test "creates a game with human player and 3 AI players" do
      game = PracticeGame.create_test_game("TestPlayer")

      assert %Game{} = game
      assert length(game.players) == 4
      assert game.status == :playing

      # Check human player
      human_player = Enum.find(game.players, &(&1.id == "human"))
      assert human_player.name == "TestPlayer"
      refute human_player.is_ai

      # Check AI players
      ai_players = Enum.filter(game.players, & &1.is_ai)
      assert length(ai_players) == 3

      ai_names = Enum.map(ai_players, & &1.name)
      ai_ids = Enum.map(ai_players, & &1.id)

      assert ai_ids == ["ai1", "ai2", "ai3"]
      assert Enum.all?(ai_names, &(&1 in PracticeGame.get_ai_names()))
    end

    test "uses random AI names from the available list" do
      game1 = PracticeGame.create_test_game("Player1")
      game2 = PracticeGame.create_test_game("Player2")

      ai_names_1 = game1.players |> Enum.filter(& &1.is_ai) |> Enum.map(& &1.name)
      ai_names_2 = game2.players |> Enum.filter(& &1.is_ai) |> Enum.map(& &1.name)

      # Names should be from the available list
      available_names = PracticeGame.get_ai_names()
      assert Enum.all?(ai_names_1, &(&1 in available_names))
      assert Enum.all?(ai_names_2, &(&1 in available_names))

      # They should be unique within each game
      assert length(Enum.uniq(ai_names_1)) == 3
      assert length(Enum.uniq(ai_names_2)) == 3
    end
  end

  describe "create_custom_test_game/2" do
    test "creates game with custom AI count" do
      game = PracticeGame.create_custom_test_game("TestPlayer", 2)

      # 1 human + 2 AI
      assert length(game.players) == 3
      assert length(Enum.filter(game.players, & &1.is_ai)) == 2
    end

    test "defaults to 3 AI players when count not specified" do
      game = PracticeGame.create_custom_test_game("TestPlayer")

      # 1 human + 3 AI
      assert length(game.players) == 4
      assert length(Enum.filter(game.players, & &1.is_ai)) == 3
    end

    test "handles maximum AI count" do
      game = PracticeGame.create_custom_test_game("TestPlayer", 7)

      # 1 human + 7 AI
      assert length(game.players) == 8
      assert length(Enum.filter(game.players, & &1.is_ai)) == 7
    end
  end

  describe "create_difficulty_test_game/2" do
    test "creates game with difficulty-based AI names" do
      easy_game = PracticeGame.create_difficulty_test_game("TestPlayer", :easy)
      medium_game = PracticeGame.create_difficulty_test_game("TestPlayer", :medium)
      hard_game = PracticeGame.create_difficulty_test_game("TestPlayer", :hard)

      easy_names = easy_game.players |> Enum.filter(& &1.is_ai) |> Enum.map(& &1.name)
      medium_names = medium_game.players |> Enum.filter(& &1.is_ai) |> Enum.map(& &1.name)
      hard_names = hard_game.players |> Enum.filter(& &1.is_ai) |> Enum.map(& &1.name)

      # Easy should use beginner names
      assert Enum.all?(easy_names, &(&1 in ["Newbie", "Learner", "Student"]))

      # Medium should use standard names
      assert Enum.all?(medium_names, &(&1 in PracticeGame.get_ai_names()))

      # Hard should use expert names
      assert Enum.all?(hard_names, &(&1 in ["Expert", "Master", "Champion"]))
    end

    test "defaults to medium difficulty" do
      game = PracticeGame.create_difficulty_test_game("TestPlayer")
      ai_names = game.players |> Enum.filter(& &1.is_ai) |> Enum.map(& &1.name)

      assert Enum.all?(ai_names, &(&1 in PracticeGame.get_ai_names()))
    end
  end

  describe "get_ai_names/0" do
    test "returns list of available AI names" do
      names = PracticeGame.get_ai_names()

      assert is_list(names)
      assert length(names) > 0
      assert "Alice" in names
      assert "Bob" in names
      assert "Charlie" in names
    end
  end
end
