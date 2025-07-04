defmodule Test.GameBuilder do
  @moduledoc """
  Test helpers for building game states in a fluent, readable way.

  Example usage:
      game = GameBuilder.new()
        |> GameBuilder.with_players([{"p1", "Alice", false}, {"p2", "Bob", false}])
        |> GameBuilder.start_game()
        |> GameBuilder.set_current_player("p1")
        |> GameBuilder.set_current_card(%Card{suit: :hearts, rank: 3})
        |> GameBuilder.give_cards("p1", [%Card{suit: :hearts, rank: 7}])
  """

  alias Rachel.Games.{Card, Game}

  @doc "Creates a new game with optional ID"
  def new(id \\ "test-game") do
    Game.new(id)
  end

  @doc "Adds multiple players to the game"
  def with_players(game, player_configs) do
    Enum.reduce(player_configs, game, fn {id, name, is_ai}, acc ->
      Game.add_player(acc, id, name, is_ai)
    end)
  end

  @doc "Adds a single player to the game"
  def with_player(game, id, name, is_ai \\ false) do
    Game.add_player(game, id, name, is_ai)
  end

  @doc "Starts the game (requires at least 2 players)"
  def start_game(game) do
    Game.start_game(game)
  end

  @doc "Sets the current player by player_id"
  def set_current_player(game, player_id) do
    case Enum.find_index(game.players, &(&1.id == player_id)) do
      nil -> raise "Player #{player_id} not found in game"
      index -> %{game | current_player_index: index}
    end
  end

  @doc "Sets the current card on the discard pile"
  def set_current_card(game, card) do
    %{game | current_card: card}
  end

  @doc "Gives specific cards to a player (replaces their hand)"
  def give_cards(game, player_id, cards) do
    players =
      Enum.map(game.players, fn player ->
        if player.id == player_id do
          %{player | hand: cards}
        else
          player
        end
      end)

    %{game | players: players}
  end

  @doc "Adds cards to a player's existing hand"
  def add_cards(game, player_id, cards) do
    players =
      Enum.map(game.players, fn player ->
        if player.id == player_id do
          %{player | hand: player.hand ++ cards}
        else
          player
        end
      end)

    %{game | players: players}
  end

  @doc "Sets the game direction"
  def set_direction(game, direction) when direction in [:clockwise, :counterclockwise] do
    %{game | direction: direction}
  end

  @doc "Sets pending pickups state"
  def set_pending_pickups(game, count, type \\ nil) do
    %{game | pending_pickups: count, pending_pickup_type: type}
  end

  @doc "Sets pending skips"
  def set_pending_skips(game, count) do
    %{game | pending_skips: count}
  end

  @doc "Sets nominated suit"
  def set_nominated_suit(game, suit)
      when suit in [:hearts, :diamonds, :clubs, :spades, :pending, nil] do
    %{game | nominated_suit: suit}
  end

  @doc "Sets game status"
  def set_status(game, status) when status in [:waiting, :playing, :finished] do
    %{game | status: status}
  end

  @doc "Adds player(s) to winners list"
  def add_winners(game, winner_ids) when is_list(winner_ids) do
    %{game | winners: game.winners ++ winner_ids}
  end

  def add_winners(game, winner_id) when is_binary(winner_id) do
    add_winners(game, [winner_id])
  end

  @doc "Creates a typical 2-player game ready to play"
  def two_player_game(p1_id \\ "p1", p2_id \\ "p2") do
    new()
    |> with_players([{p1_id, "Player 1", false}, {p2_id, "Player 2", false}])
    |> start_game()
  end

  @doc "Creates a 2-player game with one AI"
  def human_vs_ai_game(human_id \\ "human", ai_id \\ "ai") do
    new()
    |> with_players([{human_id, "Human", false}, {ai_id, "Computer", true}])
    |> start_game()
  end

  @doc "Creates a 3-player game for testing multi-player scenarios"
  def three_player_game(p1_id \\ "p1", p2_id \\ "p2", p3_id \\ "p3") do
    new()
    |> with_players([
      {p1_id, "Player 1", false},
      {p2_id, "Player 2", false},
      {p3_id, "Player 3", false}
    ])
    |> start_game()
  end

  @doc "Sets up a game for testing special card effects"
  def special_card_scenario(card, target_player_id) do
    two_player_game()
    |> set_current_player(target_player_id)
    # Safe card to play on
    |> set_current_card(%Card{suit: card.suit, rank: 3})
    |> give_cards(target_player_id, [card])
  end

  @doc "Sets up a game where a player is about to win"
  def winning_scenario(player_id, winning_card) do
    two_player_game()
    |> set_current_player(player_id)
    # Safe to play on
    |> set_current_card(%Card{suit: winning_card.suit, rank: 5})
    # Only one card left
    |> give_cards(player_id, [winning_card])
  end

  @doc "Sets up a scenario with pending 2s pickups"
  def pending_twos_scenario(player_id, num_twos \\ 1) do
    two_player_game()
    |> set_current_player(player_id)
    |> set_current_card(%Card{suit: :hearts, rank: 2})
    |> set_pending_pickups(num_twos * 2, :twos)
  end

  @doc "Sets up a scenario with pending black jack pickups"
  def pending_black_jacks_scenario(player_id, num_jacks \\ 1) do
    two_player_game()
    |> set_current_player(player_id)
    |> set_current_card(%Card{suit: :spades, rank: :jack})
    |> set_pending_pickups(num_jacks * 5, :black_jacks)
  end

  @doc "Sets up a scenario with nominated suit"
  def nominated_suit_scenario(player_id, suit) do
    two_player_game()
    |> set_current_player(player_id)
    |> set_current_card(%Card{suit: :hearts, rank: :ace})
    |> set_nominated_suit(suit)
  end

  @doc "Helper to create common card combinations"
  def cards(specs) when is_list(specs) do
    Enum.map(specs, &card/1)
  end

  def card({suit, rank}) do
    %Card{suit: suit, rank: rank}
  end

  def card(spec) when is_binary(spec) do
    # Parse strings like "7H", "AS", "KC" 
    case String.split_at(spec, -1) do
      {rank_str, suit_str} ->
        rank = parse_rank(rank_str)
        suit = parse_suit(suit_str)
        %Card{suit: suit, rank: rank}
    end
  end

  # Private helpers for string parsing
  defp parse_rank("A"), do: :ace
  defp parse_rank("K"), do: :king
  defp parse_rank("Q"), do: :queen
  defp parse_rank("J"), do: :jack

  defp parse_rank(num_str) when num_str in ~w[2 3 4 5 6 7 8 9 10] do
    String.to_integer(num_str)
  end

  defp parse_suit("H"), do: :hearts
  defp parse_suit("D"), do: :diamonds
  defp parse_suit("C"), do: :clubs
  defp parse_suit("S"), do: :spades
end
