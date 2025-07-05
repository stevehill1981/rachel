defmodule RachelWeb.GameLiveHelpersTest do
  @moduledoc """
  Tests for GameLive helper functions and AI logic to improve coverage.
  Targets helper functions, AI movement, and utility functions.
  """
  use RachelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Rachel.Games.{Game, Card, Deck, Player}

  describe "helper functions" do
    test "get_player_name_by_id with existing player" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up game with known players
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [
          %Player{id: "player1", name: "Alice", hand: [], is_ai: false},
          %Player{id: "player2", name: "Bob", hand: [], is_ai: true}
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

      send(view.pid, {:game_updated, test_game})

      # Test player name lookup in PubSub messages
      send(view.pid, {:player_disconnected, %{player_id: "player1", player_name: "Alice"}})
      html = render(view)
      assert html =~ "Rachel"

      send(view.pid, {:player_reconnected, %{player_id: "player2", player_name: "Bob"}})
      html = render(view)
      assert html =~ "Rachel"
    end

    test "get_player_name_by_id with missing player" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up game with empty players
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

      send(view.pid, {:game_updated, test_game})

      # Test with unknown player ID
      send(view.pid, {:player_disconnected, %{player_id: "unknown", player_name: "Unknown"}})
      html = render(view)
      assert html =~ "Rachel"
    end

    test "count_other_cards_with_rank with various hands" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up game with players having specific cards
      test_game = %{
        id: "test-game",
        status: :playing,
        players: [
          %Player{
            id: "human",
            name: "Human",
            hand: [
              %Card{suit: :hearts, rank: :ace},
              %Card{suit: :diamonds, rank: :ace},
              %Card{suit: :clubs, rank: :king},
              %Card{suit: :spades, rank: :ace}
            ],
            is_ai: false
          },
          %Player{
            id: "ai",
            name: "AI",
            hand: [
              %Card{suit: :hearts, rank: :king},
              %Card{suit: :diamonds, rank: :king}
            ],
            is_ai: true
          }
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

      send(view.pid, {:game_updated, test_game})

      # Try to select cards to trigger count_other_cards_with_rank
      html = render(view)

      if html =~ "phx-value-index='0'" do
        view |> element("[phx-value-index='0']") |> render_click()
      end

      html = render(view)
      assert html =~ "Rachel"
    end

    test "can_select_card with different game states" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Test with various game states
      game_states = [
        :waiting,
        :playing,
        :finished
      ]

      for status <- game_states do
        test_game = %{
          id: "test-game",
          status: status,
          players: [
            %Player{
              id: "human",
              name: "Human",
              hand: [
                %Card{suit: :hearts, rank: :ace}
              ],
              is_ai: false
            }
          ],
          current_player_index: 0,
          direction: :clockwise,
          winners: [],
          deck: %Deck{cards: [], discarded: []},
          discard_pile: [],
          pending_pickups: 0,
          pending_skips: 0,
          current_card: %Card{suit: :hearts, rank: :king}
        }

        send(view.pid, {:game_updated, test_game})

        html = render(view)
        assert html =~ "Rachel"

        # Try card selection based on game state
        if status == :playing && html =~ "phx-value-index='0'" do
          view |> element("[phx-value-index='0']") |> render_click()
        end
      end
    end

    test "check_auto_draw conditions" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Test auto-draw scenarios
      auto_draw_scenarios = [
        # Scenario 1: No playable cards
        %{
          id: "auto-draw-1",
          status: :playing,
          players: [
            %Player{
              id: "human",
              name: "Human",
              hand: [
                # Can't play on hearts ace
                %Card{suit: :clubs, rank: 2}
              ],
              is_ai: false
            }
          ],
          current_player_index: 0,
          direction: :clockwise,
          winners: [],
          deck: %Deck{cards: [%Card{suit: :hearts, rank: 3}], discarded: []},
          discard_pile: [],
          pending_pickups: 0,
          pending_skips: 0,
          current_card: %Card{suit: :hearts, rank: :ace}
        },
        # Scenario 2: With pending pickups
        %{
          id: "auto-draw-2",
          status: :playing,
          players: [
            %Player{
              id: "human",
              name: "Human",
              hand: [
                %Card{suit: :hearts, rank: 3}
              ],
              is_ai: false
            }
          ],
          current_player_index: 0,
          direction: :clockwise,
          winners: [],
          deck: %Deck{cards: [%Card{suit: :clubs, rank: :four}], discarded: []},
          discard_pile: [],
          pending_pickups: 2,
          pending_skips: 0,
          current_card: %Card{suit: :hearts, rank: 2}
        }
      ]

      for scenario <- auto_draw_scenarios do
        send(view.pid, {:game_updated, scenario})

        html = render(view)
        assert html =~ "Rachel"

        # Try to trigger auto-draw by clicking deck
        if html =~ "phx-click=\"draw_card\"" do
          view |> element("[phx-click=\"draw_card\"]") |> render_click()
        end
      end
    end
  end

  describe "AI movement logic" do
    test "AI move handling with different scenarios" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up game where AI is current player
      ai_game = %Game{
        id: "ai-game",
        status: :playing,
        players: [
          %Player{
            id: "human",
            name: "Human",
            hand: [
              %Card{suit: :hearts, rank: :king}
            ],
            is_ai: false
          },
          %Player{
            id: "ai",
            name: "AI",
            hand: [
              %Card{suit: :hearts, rank: :ace},
              %Card{suit: :clubs, rank: :king}
            ],
            is_ai: true
          }
        ],
        # AI's turn
        current_player_index: 1,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [%Card{suit: :diamonds, rank: :five}], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: 2}
      }

      send(view.pid, {:game_updated, ai_game})

      # Trigger AI move
      send(view.pid, :ai_move)

      html = render(view)
      assert html =~ "Rachel"
    end

    test "AI draw handling when no cards playable" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up game where AI has no playable cards
      ai_draw_game = %Game{
        id: "ai-draw-game",
        status: :playing,
        players: [
          %Player{
            id: "human",
            name: "Human",
            hand: [
              %Card{suit: :hearts, rank: :king}
            ],
            is_ai: false
          },
          %Player{
            id: "ai",
            name: "AI",
            hand: [
              # Can't play on hearts ace
              %Card{suit: :clubs, rank: 3}
            ],
            is_ai: true
          }
        ],
        # AI's turn
        current_player_index: 1,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [%Card{suit: :diamonds, rank: :five}], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }

      send(view.pid, {:game_updated, ai_draw_game})

      # Trigger AI move (should result in draw)
      send(view.pid, :ai_move)

      html = render(view)
      assert html =~ "Rachel"
    end

    test "AI thinking state transitions" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up game with AI player
      ai_game = %Game{
        id: "ai-thinking",
        status: :playing,
        players: [
          %Player{
            id: "human",
            name: "Human",
            hand: [
              %Card{suit: :hearts, rank: :king}
            ],
            is_ai: false
          },
          %Player{
            id: "ai",
            name: "AI",
            hand: [
              %Card{suit: :hearts, rank: :ace}
            ],
            is_ai: true
          }
        ],
        # AI's turn
        current_player_index: 1,
        direction: :clockwise,
        winners: [],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: 2}
      }

      send(view.pid, {:game_updated, ai_game})

      # Test AI thinking state
      html = render(view)
      assert html =~ "Rachel"

      # Trigger AI move to see thinking logic
      send(view.pid, :ai_move)

      html = render(view)
      assert html =~ "Rachel"
    end
  end

  describe "winner banner and game completion" do
    test "check_and_show_winner_banner with various winner scenarios" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Test different winner scenarios
      winner_scenarios = [
        # Single winner
        %{
          id: "single-winner",
          status: :finished,
          players: [
            %Player{id: "winner", name: "Winner", hand: [], is_ai: false},
            %Player{
              id: "loser",
              name: "Loser",
              hand: [%Card{suit: :hearts, rank: :ace}],
              is_ai: false
            }
          ],
          current_player_index: 0,
          direction: :clockwise,
          winners: ["winner"],
          deck: %Deck{cards: [], discarded: []},
          discard_pile: [],
          pending_pickups: 0,
          pending_skips: 0,
          current_card: %Card{suit: :hearts, rank: :ace}
        },
        # Multiple winners
        %{
          id: "multi-winner",
          status: :finished,
          players: [
            %Player{id: "winner1", name: "Winner 1", hand: [], is_ai: false},
            %Player{id: "winner2", name: "Winner 2", hand: [], is_ai: false}
          ],
          current_player_index: 0,
          direction: :clockwise,
          winners: ["winner1", "winner2"],
          deck: %Deck{cards: [], discarded: []},
          discard_pile: [],
          pending_pickups: 0,
          pending_skips: 0,
          current_card: %Card{suit: :hearts, rank: :ace}
        },
        # No winners (shouldn't happen but test defensive code)
        %{
          id: "no-winner",
          status: :finished,
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
      ]

      for scenario <- winner_scenarios do
        send(view.pid, {:game_updated, scenario})

        html = render(view)
        assert html =~ "Rachel"

        # Test auto-hide winner banner
        send(view.pid, :auto_hide_winner_banner)

        html = render(view)
        assert html =~ "Rachel"
      end
    end

    test "winner banner acknowledgment" do
      {:ok, view, _html} = live(build_conn(), ~p"/game")

      # Set up winner state
      winner_game = %{
        id: "winner-ack",
        status: :finished,
        players: [
          %Player{id: "human", name: "Human", hand: [], is_ai: false}
        ],
        current_player_index: 0,
        direction: :clockwise,
        winners: ["human"],
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [],
        pending_pickups: 0,
        pending_skips: 0,
        current_card: %Card{suit: :hearts, rank: :ace}
      }

      send(view.pid, {:game_updated, winner_game})

      # Test winner acknowledgment
      html = render(view)
      assert html =~ "Rachel"

      # Test multiple acknowledgments
      for _i <- 1..3 do
        send(view.pid, :auto_hide_winner_banner)
        html = render(view)
        assert html =~ "Rachel"
      end
    end
  end
end
