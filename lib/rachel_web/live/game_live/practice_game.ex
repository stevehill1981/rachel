defmodule RachelWeb.GameLive.PracticeGame do
  @moduledoc """
  Handles practice game creation and setup for GameLive.

  This module is responsible for:
  - Creating single-player practice games
  - Setting up AI opponents with random names
  - Configuring practice game parameters
  """

  alias Rachel.Games.Game

  @ai_names [
    "Alice",
    "Bob",
    "Charlie",
    "Diana",
    "Eve",
    "Frank",
    "Grace",
    "Henry",
    "Ivy",
    "Jack",
    "Kate",
    "Liam",
    "Maya",
    "Noah",
    "Olivia",
    "Paul",
    "Quinn",
    "Ruby",
    "Sam",
    "Tara"
  ]

  @doc """
  Creates a new practice game with the given player name and 3 AI opponents.
  """
  def create_test_game(player_name) do
    selected_names = Enum.take_random(@ai_names, 3)

    Game.new()
    |> Game.add_player("human", player_name, false)
    |> Game.add_player("ai1", Enum.at(selected_names, 0), true)
    |> Game.add_player("ai2", Enum.at(selected_names, 1), true)
    |> Game.add_player("ai3", Enum.at(selected_names, 2), true)
    |> Game.start_game()
  end

  @doc """
  Gets the list of available AI names.
  """
  def get_ai_names, do: @ai_names

  @doc """
  Creates a practice game with custom AI player count.
  """
  def create_custom_test_game(player_name, ai_count \\ 3) when ai_count > 0 and ai_count <= 7 do
    selected_names = Enum.take_random(@ai_names, ai_count)

    game = Game.new() |> Game.add_player("human", player_name, false)

    game_with_ai =
      selected_names
      |> Enum.with_index(1)
      |> Enum.reduce(game, fn {ai_name, index}, acc_game ->
        Game.add_player(acc_game, "ai#{index}", ai_name, true)
      end)

    Game.start_game(game_with_ai)
  end

  @doc """
  Creates a practice game with specific AI difficulty levels (future enhancement).
  """
  def create_difficulty_test_game(player_name, difficulty \\ :medium) do
    # For now, just creates a standard game
    # Future enhancement could implement different AI behaviors
    selected_names =
      case difficulty do
        :easy -> Enum.take_random(["Newbie", "Learner", "Student"], 3)
        :medium -> Enum.take_random(@ai_names, 3)
        :hard -> Enum.take_random(["Expert", "Master", "Champion"], 3)
      end

    Game.new()
    |> Game.add_player("human", player_name, false)
    |> Game.add_player("ai1", Enum.at(selected_names, 0), true)
    |> Game.add_player("ai2", Enum.at(selected_names, 1), true)
    |> Game.add_player("ai3", Enum.at(selected_names, 2), true)
    |> Game.start_game()
  end
end
