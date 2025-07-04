defmodule RachelWeb.LiveViewTestHelpers do
  @moduledoc """
  Helper functions for LiveView tests to reduce fragility and improve readability.
  """

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  @doc """
  Clicks an element only if it's enabled. Returns :ok if clicked, :disabled if not.
  """
  def click_if_enabled(view, selector) do
    html = render(view)

    # Check if element exists and is not disabled
    cond do
      not (html =~ selector) ->
        {:error, :not_found}

      html =~ ~r/#{Regex.escape(selector)}[^>]*disabled/ ->
        {:ok, :disabled}

      true ->
        view |> element(selector) |> render_click()
        {:ok, :clicked}
    end
  end

  @doc """
  Waits for it to be a specific player's turn or times out.
  """
  def wait_for_player_turn(view, player_id, timeout \\ 5000) do
    wait_until(timeout, fn ->
      view_state = :sys.get_state(view.pid)
      game = view_state.socket.assigns[:game]

      if game do
        current_player = Enum.at(game.players, game.current_player_index)
        current_player && current_player.id == player_id
      else
        false
      end
    end)
  end

  @doc """
  Ensures the game is in a specific state before proceeding.
  """
  def ensure_game_state(view, requirements) do
    view_state = :sys.get_state(view.pid)
    game = view_state.socket.assigns[:game]

    Enum.all?(requirements, fn
      {:status, status} ->
        game && game.status == status

      {:player_turn, player_id} ->
        current_player = game && Enum.at(game.players, game.current_player_index)
        current_player && current_player.id == player_id

      {:min_players, count} ->
        game && length(game.players) >= count

      _ ->
        true
    end)
  end

  @doc """
  Sets up a game in a specific state for testing.
  """
  def setup_game_state(view, game_attrs) do
    # Send a game update to put the game in a specific state
    game = build_test_game(game_attrs)
    send(view.pid, {:game_updated, game})

    # Give LiveView time to process
    :timer.sleep(50)

    game
  end

  @doc """
  Builds a test game with sensible defaults.
  """
  def build_test_game(attrs \\ %{}) do
    defaults = %{
      id: "test-game-#{System.unique_integer()}",
      status: :playing,
      players: [
        %{id: "human", name: "Test Player", is_ai: false, hand: []},
        %{id: "ai1", name: "Computer", is_ai: true, hand: []}
      ],
      current_player_index: 0,
      current_card: %{suit: :hearts, rank: :king},
      deck: %{cards: [], discarded: []},
      discard_pile: [],
      pending_pickups: 0,
      pending_skips: 0,
      winners: [],
      direction: :clockwise
    }

    Map.merge(defaults, attrs)
  end

  @doc """
  Waits until a condition is true or times out.
  """
  def wait_until(timeout, condition_fn) do
    start_time = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn ->
      if condition_fn.() do
        :ok
      else
        :timer.sleep(50)
        :continue
      end
    end)
    |> Enum.find_value(fn
      :ok ->
        true

      :continue ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        if elapsed > timeout, do: false, else: nil
    end)
    |> Kernel.||(false)
  end

  @doc """
  Finds a clickable card in the player's hand.
  """
  def find_clickable_card(view) do
    html = render(view)

    # Find all card elements
    card_regex = ~r/phx-value-index="(\d+)"(?![^>]*disabled)/

    case Regex.scan(card_regex, html) do
      [] ->
        nil

      matches ->
        # Return the first clickable card index
        [_, index] = hd(matches)
        String.to_integer(index)
    end
  end

  @doc """
  Asserts game is in a valid state (has all required fields).
  """
  def assert_valid_game_state(view) do
    view_state = :sys.get_state(view.pid)
    game = view_state.socket.assigns[:game]

    assert game != nil
    assert Map.has_key?(game, :players)
    assert Map.has_key?(game, :deck)
    assert Map.has_key?(game, :current_card)
    assert Map.has_key?(game, :status)
  end
end
