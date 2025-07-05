defmodule RachelWeb.GameLive.EventHandlersTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Socket
  alias Rachel.Games.{Card, Game, Player}
  alias RachelWeb.GameLive.EventHandlers

  describe "handle_card_selection/3" do
    test "deselects card when already selected" do
      selected_cards = [0, 1, 2]
      current_player = %Player{id: "p1", name: "Test", hand: test_hand()}

      result = EventHandlers.handle_card_selection(selected_cards, current_player, 1)

      assert {:ok, {:assign, :selected_cards, [0, 2]}} = result
    end

    test "selects card when not already selected" do
      selected_cards = [0]
      current_player = %Player{id: "p1", name: "Test", hand: test_hand()}

      result = EventHandlers.handle_card_selection(selected_cards, current_player, 2)

      assert {:ok, {:assign, :selected_cards, [0, 2]}} = result
    end

    test "handles invalid card index" do
      selected_cards = []
      current_player = %Player{id: "p1", name: "Test", hand: test_hand()}

      # Index beyond hand size
      result = EventHandlers.handle_card_selection(selected_cards, current_player, 10)

      assert {:error, :invalid_card} = result
    end
  end

  describe "handle_play_cards/3" do
    setup do
      game = %Game{
        id: "test-game",
        status: :playing,
        current_player_index: 0,
        players: [
          %Player{id: "p1", name: "Player 1", hand: test_hand()},
          %Player{id: "p2", name: "Player 2", hand: test_hand()}
        ],
        deck: %{cards: []},
        discard_pile: [],
        current_card: %Card{suit: :hearts, rank: 5}
      }

      {:ok, game: game}
    end

    test "accepts valid play cards request", %{game: game} do
      result = EventHandlers.handle_play_cards(game, "p1", [0])

      assert {:ok, {:play_cards_action, [0]}} = result
    end

    test "rejects play cards when not current player", %{game: game} do
      result = EventHandlers.handle_play_cards(game, "p2", [0])

      assert {:error, :invalid_request} = result
    end

    test "rejects play cards with empty selection", %{game: game} do
      result = EventHandlers.handle_play_cards(game, "p1", [])

      assert {:error, :invalid_request} = result
    end

    test "accepts play with multiple cards selected", %{game: game} do
      result = EventHandlers.handle_play_cards(game, "p1", [0, 1, 2])

      assert {:ok, {:play_cards_action, [0, 1, 2]}} = result
    end
  end

  describe "handle_draw_card/1" do
    setup do
      socket = %Socket{
        assigns: %{
          game_id: nil,
          game: test_game(),
          player_id: "p1",
          current_player_id: "p1"
        }
      }

      {:ok, socket: socket}
    end

    test "handles successful draw card in single-player game", %{socket: socket} do
      # Mock the Actions module
      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :draw_card_action, fn _socket ->
        {:ok, test_game()}
      end)

      result = EventHandlers.handle_draw_card(socket)

      assert {:ok, updates} = result

      assert Enum.any?(updates, fn
               {:assign, :game, _} -> true
               _ -> false
             end)

      assert {:assign, :selected_cards, []} in updates
      assert {:clear_flash} in updates
      assert {:put_flash, :info, "Card drawn!"} in updates

      assert Enum.any?(updates, fn
               {:schedule_ai_move, _} -> true
               _ -> false
             end)

      :meck.unload(RachelWeb.GameLive.Actions)
    end

    test "handles successful draw card in multiplayer game", %{socket: socket} do
      socket = %{socket | assigns: %{socket.assigns | game_id: "game-123"}}

      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :draw_card_action, fn _socket ->
        {:ok, test_game()}
      end)

      result = EventHandlers.handle_draw_card(socket)

      assert {:ok, updates} = result
      # Should not include AI scheduling for multiplayer
      refute Enum.any?(updates, fn
               {:schedule_ai_move, _} -> true
               _ -> false
             end)

      :meck.unload(RachelWeb.GameLive.Actions)
    end

    test "handles draw card error", %{socket: socket} do
      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :draw_card_action, fn _socket ->
        {:error, :cannot_draw}
      end)

      :meck.expect(RachelWeb.GameLive.Actions, :format_error, fn :cannot_draw ->
        "Cannot draw card"
      end)

      result = EventHandlers.handle_draw_card(socket)

      assert {:error, "Cannot draw card"} = result

      :meck.unload(RachelWeb.GameLive.Actions)
    end
  end

  describe "handle_nominate_suit/3" do
    setup do
      socket = %Socket{
        assigns: %{
          game_id: nil,
          game: test_game(),
          player_id: "p1",
          current_player_id: "p1"
        }
      }

      {:ok, socket: socket}
    end

    test "handles successful suit nomination in single-player", %{socket: socket} do
      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :nominate_suit_action, fn _socket, :hearts ->
        {:ok, test_game()}
      end)

      result = EventHandlers.handle_nominate_suit(socket, :hearts, "Hearts")

      assert {:ok, updates} = result

      assert Enum.any?(updates, fn
               {:assign, :game, _} -> true
               _ -> false
             end)

      assert {:clear_flash} in updates
      assert {:put_flash, :info, "Suit nominated: Hearts"} in updates

      assert Enum.any?(updates, fn
               {:schedule_ai_move, _} -> true
               _ -> false
             end)

      :meck.unload(RachelWeb.GameLive.Actions)
    end

    test "handles successful suit nomination in multiplayer", %{socket: socket} do
      socket = %{socket | assigns: %{socket.assigns | game_id: "game-123"}}

      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :nominate_suit_action, fn _socket, :spades ->
        {:ok, test_game()}
      end)

      result = EventHandlers.handle_nominate_suit(socket, :spades, "Spades")

      assert {:ok, updates} = result
      assert {:put_flash, :info, "Suit nominated: Spades"} in updates
      # Should not include AI scheduling for multiplayer
      refute Enum.any?(updates, fn
               {:schedule_ai_move, _} -> true
               _ -> false
             end)

      :meck.unload(RachelWeb.GameLive.Actions)
    end

    test "handles suit nomination error", %{socket: socket} do
      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :nominate_suit_action, fn _socket, _suit ->
        {:error, :not_your_turn}
      end)

      :meck.expect(RachelWeb.GameLive.Actions, :format_error, fn :not_your_turn ->
        "Not your turn"
      end)

      result = EventHandlers.handle_nominate_suit(socket, :clubs, "Clubs")

      assert {:error, "Not your turn"} = result

      :meck.unload(RachelWeb.GameLive.Actions)
    end
  end

  describe "can_select_card?/4" do
    setup do
      game = %Game{
        id: "test-game",
        status: :playing,
        current_player_index: 0,
        players: [
          %Player{id: "p1", name: "Player 1", hand: test_hand()},
          %Player{id: "p2", name: "Player 2", hand: []}
        ],
        deck: %{cards: []},
        discard_pile: [],
        current_card: %Card{suit: :hearts, rank: 5}
      }

      {:ok, game: game}
    end

    test "allows selecting valid card when nothing selected", %{game: game} do
      card = %Card{suit: :hearts, rank: 9}
      hand = test_hand()

      # Mock Game.current_player
      :meck.new(Game, [:passthrough])

      :meck.expect(Game, :current_player, fn _game ->
        %Player{id: "p1", name: "Player 1", hand: hand}
      end)

      :meck.expect(Game, :get_valid_plays, fn _game, _player ->
        [{%Card{suit: :hearts, rank: 9}, 0}, {%Card{suit: :diamonds, rank: 5}, 2}]
      end)

      result = EventHandlers.can_select_card?(game, card, [], hand)

      assert result == true

      :meck.unload(Game)
    end

    test "disallows selecting invalid card when nothing selected", %{game: game} do
      card = %Card{suit: :spades, rank: 3}
      hand = test_hand()

      :meck.new(Game, [:passthrough])

      :meck.expect(Game, :current_player, fn _game ->
        %Player{id: "p1", name: "Player 1", hand: hand}
      end)

      :meck.expect(Game, :get_valid_plays, fn _game, _player ->
        [{%Card{suit: :hearts, rank: 9}, 0}, {%Card{suit: :diamonds, rank: 5}, 2}]
      end)

      result = EventHandlers.can_select_card?(game, card, [], hand)

      assert result == false

      :meck.unload(Game)
    end

    test "allows selecting card with same rank when cards already selected", %{game: game} do
      card = %Card{suit: :spades, rank: 5}
      hand = test_hand()
      # Index 2 has rank 5
      selected_indices = [2]

      result = EventHandlers.can_select_card?(game, card, selected_indices, hand)

      assert result == true
    end

    test "disallows selecting card with different rank when cards already selected", %{game: game} do
      card = %Card{suit: :hearts, rank: 9}
      hand = test_hand()
      # Index 2 has rank 5
      selected_indices = [2]

      result = EventHandlers.can_select_card?(game, card, selected_indices, hand)

      assert result == false
    end

    test "handles invalid selected index gracefully", %{game: game} do
      card = %Card{suit: :hearts, rank: 9}
      hand = test_hand()
      # Invalid index
      selected_indices = [10]

      result = EventHandlers.can_select_card?(game, card, selected_indices, hand)

      assert result == false
    end
  end

  describe "StateManager integration" do
    test "normalize_game_data is called when handling events" do
      socket = %Socket{
        assigns: %{
          game_id: nil,
          game: test_game(),
          player_id: "p1"
        }
      }

      :meck.new(RachelWeb.GameLive.Actions, [:passthrough])
      :meck.new(RachelWeb.GameLive.StateManager, [:passthrough])

      :meck.expect(RachelWeb.GameLive.Actions, :draw_card_action, fn _socket ->
        {:ok, test_game()}
      end)

      :meck.expect(RachelWeb.GameLive.StateManager, :normalize_game_data, fn game ->
        game
      end)

      EventHandlers.handle_draw_card(socket)

      # Verify normalize_game_data was called
      assert :meck.called(RachelWeb.GameLive.StateManager, :normalize_game_data, [:_])

      :meck.unload(RachelWeb.GameLive.Actions)
      :meck.unload(RachelWeb.GameLive.StateManager)
    end
  end

  # Helper functions

  defp test_hand do
    [
      %Card{suit: :hearts, rank: 9},
      %Card{suit: :spades, rank: 9},
      %Card{suit: :diamonds, rank: 5},
      %Card{suit: :clubs, rank: 3}
    ]
  end

  defp test_game do
    %Game{
      id: "test-game",
      status: :playing,
      current_player_index: 0,
      players: [
        %Player{id: "p1", name: "Player 1", hand: test_hand()},
        %Player{id: "p2", name: "Player 2", hand: test_hand()}
      ],
      deck: %{cards: []},
      discard_pile: [],
      current_card: %Card{suit: :hearts, rank: 5},
      direction: :clockwise,
      pending_pickups: 0,
      pending_skips: 0,
      nominated_suit: nil,
      winners: []
    }
  end
end
