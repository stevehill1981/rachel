defmodule RachelWeb.GameLivePubSubTest do
  @moduledoc """
  Tests for GameLive PubSub message handling to improve coverage.
  Targets handle_info messages and edge cases.
  """
  use RachelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Rachel.Games.{Card, Deck, Player}

  describe "PubSub message handlers" do
    test "handles cards_played message with various scenarios" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      # Create test card and game context
      test_card = %Card{suit: :hearts, rank: :ace}
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [
          %Player{id: "player1", name: "Player 1", hand: [], is_ai: false},
          %Player{id: "player2", name: "Player 2", hand: [], is_ai: true}
        ],
        current_card: test_card,
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0
      }
      
      # Test cards_played message
      send(view.pid, {:cards_played, %{
        player_id: "player1",
        cards: [test_card],
        game: test_game
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles card_drawn message with player lookup" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [
          %Player{id: "drawer", name: "Card Drawer", hand: [], is_ai: false}
        ],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test card_drawn message
      send(view.pid, {:card_drawn, %{
        player_id: "drawer",
        game: test_game
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles card_drawn message with unknown player" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test card_drawn message with unknown player
      send(view.pid, {:card_drawn, %{
        player_id: "unknown_player",
        game: test_game
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles suit_nominated message with various suits" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [
          %Player{id: "nominator", name: "Suit Nominator", hand: [], is_ai: false}
        ],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test all suits
      for suit <- [:hearts, :diamonds, :clubs, :spades] do
        send(view.pid, {:suit_nominated, %{
          player_id: "nominator",
          suit: suit,
          game: test_game
        }})
        
        html = render(view)
        assert html =~ "Rachel"
      end
    end

    test "handles suit_nominated message with unknown player" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test suit_nominated with unknown player
      send(view.pid, {:suit_nominated, %{
        player_id: "unknown_nominator",
        suit: :hearts,
        game: test_game
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles player_disconnected message" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      # Test player disconnected
      send(view.pid, {:player_disconnected, %{
        player_id: "disconnected_player",
        player_name: "Disconnected Player"
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles player_reconnected message" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      # Test player reconnected
      send(view.pid, {:player_reconnected, %{
        player_id: "reconnected_player",
        player_name: "Reconnected Player"
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles player_won message" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      winning_game = %{
        id: "test-game",
        status: :finished,
        players: [
          %Player{id: "winner", name: "Winner", hand: [], is_ai: false}
        ],
        current_player_index: 0,
        direction: :clockwise,
        winners: ["winner"],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test player won
      send(view.pid, {:player_won, %{
        player_id: "winner",
        game: winning_game
      }})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles game_started message" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      started_game = %{
        id: "test-game",
        status: :playing,
        players: [
          %Player{id: "player1", name: "Player 1", hand: [], is_ai: false},
          %Player{id: "player2", name: "Player 2", hand: [], is_ai: true}
        ],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test game started
      send(view.pid, {:game_started, started_game})
      
      html = render(view)
      assert html =~ "Rachel"
    end

    test "handles game_ended message" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      ended_game = %{
        id: "test-game",
        status: :finished,
        players: [],
        current_player_index: 0,
        direction: :clockwise,
        winners: ["winner"],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test game ended
      send(view.pid, {:game_ended, ended_game})
      
      html = render(view)
      assert html =~ "Rachel"
    end
  end

  describe "PubSub message edge cases" do
    test "handles messages with minimal game data" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      minimal_game = %{
        id: "minimal",
        status: :playing,
        players: [],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Test various messages with minimal game data
      messages = [
        {:cards_played, %{player_id: "ghost", cards: [], game: minimal_game}},
        {:card_drawn, %{player_id: "ghost", game: minimal_game}},
        {:suit_nominated, %{player_id: "ghost", suit: :hearts, game: minimal_game}},
        {:player_won, %{player_id: "ghost", game: minimal_game}},
        {:game_started, minimal_game},
        {:game_ended, minimal_game}
      ]
      
      for message <- messages do
        send(view.pid, message)
        html = render(view)
        assert html =~ "Rachel"
      end
    end

    test "handles concurrent message processing" do
      {:ok, view, _html} = live(build_conn(), ~p"/play")
      
      test_game = %{
        id: "concurrent-test",
        status: :playing,
        players: [
          %Player{id: "player1", name: "Player 1", hand: [], is_ai: false}
        ],
        current_player_index: 0,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }
      
      # Send multiple messages rapidly
      for i <- 1..5 do
        send(view.pid, {:card_drawn, %{player_id: "player1", game: test_game}})
        send(view.pid, {:player_disconnected, %{player_id: "player#{i}", player_name: "Player #{i}"}})
        send(view.pid, {:game_updated, test_game})
      end
      
      html = render(view)
      assert html =~ "Rachel"
    end
  end
end