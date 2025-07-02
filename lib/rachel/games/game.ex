defmodule Rachel.Games.Game do
  @moduledoc """
  Core game logic for Rachel card game.
  Manages game state, rules, and player actions.
  """

  alias Rachel.Games.{Card, Deck, Stats}

  @type player_id :: String.t()
  @type direction :: :clockwise | :counterclockwise
  @type game_status :: :waiting | :playing | :finished

  @type player :: %{
          id: player_id(),
          name: String.t(),
          hand: [Card.t()],
          is_ai: boolean()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          players: [player()],
          deck: Deck.t(),
          current_card: Card.t() | nil,
          current_player_index: integer(),
          direction: direction(),
          pending_pickups: integer(),
          pending_pickup_type: :twos | :black_jacks | nil,
          pending_skips: integer(),
          nominated_suit: Card.suit() | nil,
          status: game_status(),
          winners: [player_id()],
          stats: Stats.t() | nil
        }

  defstruct [
    :id,
    :deck,
    :current_card,
    players: [],
    current_player_index: 0,
    direction: :clockwise,
    pending_pickups: 0,
    pending_pickup_type: nil,
    pending_skips: 0,
    nominated_suit: nil,
    status: :waiting,
    winners: [],
    stats: nil
  ]

  def new(id \\ generate_id()) do
    %__MODULE__{id: id, deck: Deck.new()}
  end

  def add_player(%__MODULE__{status: :waiting} = game, player_id, name, is_ai \\ false) do
    player = %{id: player_id, name: name, hand: [], is_ai: is_ai}
    %{game | players: game.players ++ [player]}
  end

  def start_game(%__MODULE__{players: players} = game) when length(players) >= 2 do
    deck = Deck.new()

    # Draw first card to start the discard pile
    {first_card, deck} = Deck.draw_one(deck)
    deck = Deck.add_to_discard(deck, first_card)

    # Deal 7 cards to each player
    cards_per_player = 7
    {players_with_cards, deck} = deal_initial_hands(players, deck, cards_per_player)

    # Initialize stats tracking
    player_ids = Enum.map(players, & &1.id)
    stats = Stats.new(player_ids)

    %{
      game
      | players: players_with_cards,
        deck: deck,
        current_card: first_card,
        status: :playing,
        stats: stats
    }
  end

  def play_card(%__MODULE__{status: :playing} = game, player_id, card_indices)
      when is_list(card_indices) do
    with {:ok, player_index} <- find_player_index(game, player_id),
         true <- player_index == game.current_player_index,
         player <- Enum.at(game.players, player_index),
         {:ok, cards} <- get_cards_by_indices(player.hand, card_indices),
         {:ok, validated_cards} <- validate_play(game, cards) do
      new_game =
        game
        |> remove_cards_from_player(player_index, cards)
        |> apply_card_effects(validated_cards)
        |> update_current_card(List.last(validated_cards))
        |> record_cards_played(player_id, validated_cards)
        |> check_for_winner(player_index)

      # Only advance turn if we're not waiting for suit nomination
      new_game =
        if new_game.nominated_suit == :pending do
          new_game
        else
          advance_turn(new_game)
        end

      {:ok, new_game}
    else
      {:error, _} = error -> error
      false -> {:error, :not_your_turn}
    end
  end

  def play_card(game, player_id, card_index) when is_integer(card_index) do
    play_card(game, player_id, [card_index])
  end

  def draw_card(%__MODULE__{status: :playing} = game, player_id) do
    with {:ok, player_index} <- find_player_index(game, player_id),
         true <- player_index == game.current_player_index,
         player <- Enum.at(game.players, player_index),
         false <- has_valid_play?(game, player) do
      count = max(1, game.pending_pickups)
      {cards, new_deck} = Deck.draw(game.deck, count)

      new_game =
        game
        |> update_player_hand(player_index, player.hand ++ cards)
        |> Map.put(:deck, new_deck)
        |> Map.put(:pending_pickups, 0)
        |> Map.put(:pending_pickup_type, nil)
        |> record_cards_drawn(player_id, count)
        |> advance_turn()

      {:ok, new_game}
    else
      {:error, _} = error -> error
      false -> {:error, :not_your_turn}
      true -> {:error, :must_play_valid_card}
    end
  end

  def nominate_suit(%__MODULE__{nominated_suit: :pending} = game, player_id, suit)
      when suit in [:hearts, :diamonds, :clubs, :spades] do
    with {:ok, player_index} <- find_player_index(game, player_id),
         true <- player_index == game.current_player_index do
      new_game =
        game
        |> Map.put(:nominated_suit, suit)
        |> record_suit_nomination()
        |> advance_turn()

      {:ok, new_game}
    else
      {:error, _} = error -> error
      false -> {:error, :not_your_turn}
    end
  end

  def nominate_suit(%__MODULE__{}, _player_id, _suit) do
    {:error, :no_ace_played}
  end

  def current_player(%__MODULE__{players: players, current_player_index: index}) do
    Enum.at(players, index)
  end

  def get_valid_plays(%__MODULE__{} = game, %{hand: hand}) do
    hand
    |> Enum.with_index()
    |> Enum.filter(fn {card, _index} -> valid_play?(game, card) end)
  end

  def has_valid_play?(game, player) do
    get_valid_plays(game, player) != []
  end

  defp deal_initial_hands(players, deck, cards_per_player) do
    Enum.map_reduce(players, deck, fn player, deck_acc ->
      {cards, new_deck} = Deck.draw(deck_acc, cards_per_player)
      {%{player | hand: cards}, new_deck}
    end)
  end

  defp find_player_index(%__MODULE__{players: players}, player_id) do
    case Enum.find_index(players, &(&1.id == player_id)) do
      nil -> {:error, :player_not_found}
      index -> {:ok, index}
    end
  end

  defp get_cards_by_indices(hand, indices) do
    cards = Enum.map(indices, fn i -> Enum.at(hand, i) end)

    if Enum.any?(cards, &is_nil/1) do
      {:error, :invalid_card_index}
    else
      {:ok, cards}
    end
  end

  defp validate_play(%__MODULE__{pending_pickup_type: :twos} = _game, cards) do
    # Must play 2s to continue stacking
    if Enum.all?(cards, fn card -> card.rank == 2 end) do
      validate_stacking(cards)
    else
      {:error, :must_play_twos}
    end
  end

  defp validate_play(%__MODULE__{pending_pickup_type: :black_jacks} = _game, cards) do
    # Must play jacks to continue stacking
    if Enum.all?(cards, fn card -> card.rank == :jack end) do
      validate_stacking(cards)
    else
      {:error, :must_play_jacks}
    end
  end

  defp validate_play(%__MODULE__{nominated_suit: suit} = _game, cards) when not is_nil(suit) do
    [first_card | _] = cards

    # First card must match nominated suit or be an ace
    if first_card.suit == suit or first_card.rank == :ace do
      validate_stacking(cards)
    else
      {:error, :must_play_nominated_suit}
    end
  end

  defp validate_play(game, cards) do
    [first_card | _] = cards

    case {valid_play?(game, first_card), validate_stacking(cards)} do
      {true, {:ok, validated_cards}} -> {:ok, validated_cards}
      {false, _} -> {:error, :first_card_invalid}
      {_, {:error, reason}} -> {:error, reason}
    end
  end

  defp validate_stacking([_single_card] = cards), do: {:ok, cards}

  defp validate_stacking(cards) do
    ranks = Enum.map(cards, & &1.rank) |> Enum.uniq()

    if length(ranks) == 1 do
      {:ok, cards}
    else
      {:error, :can_only_stack_same_rank}
    end
  end

  defp valid_play?(%__MODULE__{current_card: nil}, _card), do: true

  defp valid_play?(%__MODULE__{pending_pickup_type: :twos}, card) do
    # When pending pickups are from 2s, can only play 2s
    card.rank == 2
  end

  defp valid_play?(%__MODULE__{pending_pickup_type: :black_jacks}, card) do
    # When pending pickups are from black jacks, can only play jacks
    card.rank == :jack
  end

  defp valid_play?(%__MODULE__{nominated_suit: suit}, card) when not is_nil(suit) do
    card.suit == suit or card.rank == :ace
  end

  defp valid_play?(%__MODULE__{current_card: current}, card) do
    Card.can_play_on?(card, current)
  end

  defp remove_cards_from_player(game, player_index, cards) do
    player = Enum.at(game.players, player_index)
    new_hand = Enum.reject(player.hand, fn card -> card in cards end)
    update_player_hand(game, player_index, new_hand)
  end

  defp update_player_hand(game, player_index, new_hand) do
    players =
      List.update_at(game.players, player_index, fn player ->
        %{player | hand: new_hand}
      end)

    %{game | players: players}
  end

  defp apply_card_effects(game, cards) do
    Enum.reduce(cards, game, fn card, game_acc ->
      apply_single_card_effect(game_acc, card)
    end)
  end

  defp apply_single_card_effect(game, card) do
    case Card.special_effect(card) do
      :pickup_two ->
        %{game | pending_pickups: game.pending_pickups + 2, pending_pickup_type: :twos}

      :skip_turn ->
        %{game | pending_skips: game.pending_skips + 1}

      :jack_effect ->
        handle_jack_effect(game, card)

      :reverse_direction ->
        new_direction = if game.direction == :clockwise, do: :counterclockwise, else: :clockwise

        game
        |> Map.put(:direction, new_direction)
        |> record_direction_change()

      :choose_suit ->
        # Don't advance turn yet - player needs to nominate suit
        %{game | nominated_suit: :pending}

      nil ->
        game
    end
  end

  defp handle_jack_effect(game, card) do
    cond do
      Card.black_jack?(card) ->
        %{game | pending_pickups: game.pending_pickups + 5, pending_pickup_type: :black_jacks}

      Card.red_jack?(card) and game.pending_pickup_type == :black_jacks ->
        # Red jack cancels one black jack (5 pickups)
        new_pickups = max(0, game.pending_pickups - 5)
        pickup_type = if new_pickups == 0, do: nil, else: :black_jacks
        %{game | pending_pickups: new_pickups, pending_pickup_type: pickup_type}

      true ->
        game
    end
  end

  defp update_current_card(game, card) do
    deck = Deck.add_to_discard(game.deck, card)
    %{game | current_card: card, deck: deck}
  end

  defp check_for_winner(game, player_index) do
    player = Enum.at(game.players, player_index)

    if Enum.empty?(player.hand) do
      game
      |> Map.put(:winners, game.winners ++ [player.id])
      |> record_winner(player.id)
    else
      game
    end
  end

  defp advance_turn(%__MODULE__{pending_skips: skips} = game) when skips > 0 do
    game
    |> Map.put(:pending_skips, skips - 1)
    |> increment_turn()
    |> advance_turn()
  end

  defp advance_turn(game) do
    game
    |> record_turn_advance()
    |> increment_turn()
  end

  defp increment_turn(%__MODULE__{direction: :clockwise} = game) do
    next_index = find_next_active_player(game, 1)
    %{game | current_player_index: next_index}
  end

  defp increment_turn(%__MODULE__{direction: :counterclockwise} = game) do
    next_index = find_next_active_player(game, -1)
    %{game | current_player_index: next_index}
  end

  defp find_next_active_player(game, direction) do
    player_count = length(game.players)

    # Keep incrementing until we find a player who hasn't won
    Enum.reduce_while(1..player_count, game.current_player_index, fn _, current_idx ->
      next_idx = rem(current_idx + direction + player_count, player_count)
      next_player = Enum.at(game.players, next_idx)

      if next_player.id in game.winners do
        {:cont, next_idx}
      else
        {:halt, next_idx}
      end
    end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # Stats tracking helpers
  defp record_cards_played(%__MODULE__{stats: nil} = game, _player_id, _cards), do: game

  defp record_cards_played(%__MODULE__{stats: stats} = game, player_id, cards) do
    new_stats = Stats.record_card_played(stats, player_id, cards)
    %{game | stats: new_stats}
  end

  defp record_cards_drawn(%__MODULE__{stats: nil} = game, _player_id, _count), do: game

  defp record_cards_drawn(%__MODULE__{stats: stats} = game, player_id, count) do
    new_stats = Stats.record_card_drawn(stats, player_id, count)
    %{game | stats: new_stats}
  end

  defp record_turn_advance(%__MODULE__{stats: nil} = game), do: game

  defp record_turn_advance(%__MODULE__{stats: stats} = game) do
    new_stats = Stats.record_turn_advance(stats)
    %{game | stats: new_stats}
  end

  defp record_direction_change(%__MODULE__{stats: nil} = game), do: game

  defp record_direction_change(%__MODULE__{stats: stats} = game) do
    new_stats = Stats.record_direction_change(stats)
    %{game | stats: new_stats}
  end

  defp record_suit_nomination(%__MODULE__{stats: nil} = game), do: game

  defp record_suit_nomination(%__MODULE__{stats: stats} = game) do
    new_stats = Stats.record_suit_nomination(stats)
    %{game | stats: new_stats}
  end

  defp record_winner(%__MODULE__{stats: nil} = game, _winner_id), do: game

  defp record_winner(%__MODULE__{stats: stats} = game, winner_id) do
    new_stats = Stats.record_winner(stats, winner_id)
    %{game | stats: new_stats}
  end

  def get_game_stats(%__MODULE__{stats: nil}), do: nil
  def get_game_stats(%__MODULE__{stats: stats}), do: Stats.format_stats(stats)
end
