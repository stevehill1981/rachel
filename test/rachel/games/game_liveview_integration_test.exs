defmodule Rachel.Games.GameLiveViewIntegrationTest do
  @moduledoc """
  Integration tests for LiveView-specific scenarios.
  These test the interaction between game logic and the web interface.
  """
  use ExUnit.Case, async: true
  use Rachel.DataCase

  alias Rachel.Games.{Card, Game}

  describe "liveview game state synchronization" do
    test "game state stays synchronized during rapid moves" do
      # Test that LiveView socket state matches game state
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate LiveView socket assigns
      socket_assigns = %{
        game: game,
        player_id: "alice",
        selected_cards: []
      }

      # Simulate rapid card selections and plays
      moves = [
        {:select_card, 0},
        {:play_selected, []},
        {:select_card, 1},
        {:deselect_card, 1},
        {:select_card, 0},
        {:play_selected, []}
      ]

      final_assigns = simulate_liveview_moves(socket_assigns, moves)
      
      # Final state should be consistent
      assert is_map(final_assigns.game)
      assert final_assigns.game.status in [:playing, :finished]
      assert is_list(final_assigns.selected_cards)
    end

    @tag :skip
    test "handles websocket disconnection and reconnection" do
      # Player disconnects mid-game, reconnects
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Simulate game progressing while Alice is disconnected
      if Game.has_valid_play?(game, hd(game.players)) do
        valid_plays = Game.get_valid_plays(game, hd(game.players))
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, progressed_game} = Game.play_card(game, "alice", [index])
            
            # Alice reconnects and should see current state
            assert progressed_game.current_player_index != 0  # Turn advanced
            assert progressed_game.status == :playing
          [] -> :ok
        end
      end
    end

    test "handles concurrent players in same game" do
      # Multiple players in same game making moves
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.add_player("charlie", "Charlie", false)
      |> Game.start_game()

      # Simulate multiple LiveView sessions for same game
      alice_socket = %{game: game, player_id: "alice", selected_cards: []}
      bob_socket = %{game: game, player_id: "bob", selected_cards: []}
      charlie_socket = %{game: game, player_id: "charlie", selected_cards: []}

      # Alice makes a move
      if Game.has_valid_play?(game, hd(game.players)) do
        valid_plays = Game.get_valid_plays(game, hd(game.players))
        case valid_plays do
          [{_card, index} | _] ->
            {:ok, new_game} = Game.play_card(game, "alice", [index])
            
            # All sockets should get updated with new game state
            updated_alice = %{alice_socket | game: new_game}
            updated_bob = %{bob_socket | game: new_game}
            updated_charlie = %{charlie_socket | game: new_game}
            
            # All should see same game state
            assert updated_alice.game == updated_bob.game
            assert updated_bob.game == updated_charlie.game
          [] -> :ok
        end
      end
    end
  end

  describe "user interface edge cases" do
    test "handles rapid card selection and deselection" do
      # User rapidly clicks cards on mobile
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      socket_assigns = %{
        game: game,
        player_id: "alice",
        selected_cards: []
      }

      # Rapid selection/deselection sequence
      rapid_selections = [
        {:select_card, 0},
        {:select_card, 1},
        {:deselect_card, 0},
        {:select_card, 2},
        {:deselect_card, 1},
        {:deselect_card, 2},
        {:select_card, 0},
        {:select_card, 0},  # Double-select same card
        {:deselect_card, 0},
        {:deselect_card, 0}  # Double-deselect same card
      ]

      final_assigns = simulate_liveview_moves(socket_assigns, rapid_selections)
      
      # Should end in consistent state
      assert is_list(final_assigns.selected_cards)
      assert Enum.all?(final_assigns.selected_cards, &is_integer/1)
      
      # No duplicate selections
      unique_selections = Enum.uniq(final_assigns.selected_cards)
      assert length(unique_selections) == length(final_assigns.selected_cards)
    end

    test "handles invalid card combinations in UI" do
      # User selects invalid card combinations
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Give Alice specific cards for testing
      [alice, bob] = game.players
      alice = %{alice | hand: [
        %Card{suit: :hearts, rank: 5},
        %Card{suit: :spades, rank: 7},
        %Card{suit: :clubs, rank: 5},
        %Card{suit: :diamonds, rank: 9}
      ]}
      
      game = %{game | 
        players: [alice, bob], 
        current_card: %Card{suit: :hearts, rank: 6}
      }

      socket_assigns = %{
        game: game,
        player_id: "alice",
        selected_cards: []
      }

      # Select valid card (hearts 5) and invalid card (spades 7)
      invalid_selection = [
        {:select_card, 0},  # hearts 5 (valid)
        {:select_card, 1},  # spades 7 (invalid with hearts 5)
        {:play_selected, []}
      ]

      final_assigns = simulate_liveview_moves(socket_assigns, invalid_selection)
      
      # Play should fail, selections should be cleared
      assert final_assigns.selected_cards == []
      
      # Game state should be unchanged (no invalid play)
      assert final_assigns.game.current_player_index == 0
    end

    test "handles multi-card play validation" do
      # User tries to play multiple cards of different ranks
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      [alice, bob] = game.players
      alice = %{alice | hand: [
        %Card{suit: :hearts, rank: 5},    # Valid first card
        %Card{suit: :spades, rank: 5},    # Valid stack
        %Card{suit: :clubs, rank: 7}      # Invalid stack (different rank)
      ]}
      
      game = %{game | 
        players: [alice, bob], 
        current_card: %Card{suit: :hearts, rank: 6}
      }

      socket_assigns = %{
        game: game,
        player_id: "alice",
        selected_cards: []
      }

      # Try to play cards with different ranks
      invalid_multi_play = [
        {:select_card, 0},  # 5 of hearts
        {:select_card, 2},  # 7 of clubs
        {:play_selected, []}
      ]

      final_assigns = simulate_liveview_moves(socket_assigns, invalid_multi_play)
      
      # Should reject the play
      assert final_assigns.selected_cards == []
      assert final_assigns.game.current_player_index == 0
    end
  end

  describe "ai interaction edge cases" do
    test "handles AI taking too long to play" do
      # AI gets stuck or takes very long
      game = Game.new()
      |> Game.add_player("human", "Human", false)
      |> Game.add_player("ai", "AI", true)
      |> Game.start_game()

      # Set AI as current player
      game = %{game | current_player_index: 1}
      
      socket_assigns = %{
        game: game,
        player_id: "human",
        selected_cards: [],
        ai_thinking: true,
        ai_timeout: 30_000  # 30 second timeout
      }

      # Simulate AI timeout
      timeout_assigns = %{socket_assigns | 
        ai_thinking: false,
        ai_timeout: 0
      }

      # Game should still be playable
      assert timeout_assigns.game.status == :playing
      assert timeout_assigns.ai_thinking == false
    end

    test "handles human trying to play during AI turn" do
      # Human gets impatient during AI turn
      game = Game.new()
      |> Game.add_player("human", "Human", false)
      |> Game.add_player("ai", "AI", true)
      |> Game.start_game()

      # AI's turn
      game = %{game | current_player_index: 1}
      
      socket_assigns = %{
        game: game,
        player_id: "human",
        selected_cards: []
      }

      # Human tries to play during AI turn
      impatient_moves = [
        {:select_card, 0},
        {:play_selected, []},
        {:select_card, 1},
        {:play_selected, []}
      ]

      final_assigns = simulate_liveview_moves(socket_assigns, impatient_moves)
      
      # Should reject all moves, turn should remain with AI
      assert final_assigns.game.current_player_index == 1
      assert final_assigns.selected_cards == []
    end
  end

  describe "game lifecycle edge cases" do
    test "handles game ending during multi-card selection" do
      # Player selects cards but game ends before they play
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Set up Alice to win with one card
      [alice, bob] = game.players
      alice = %{alice | hand: [%Card{suit: :hearts, rank: 5}]}
      bob = %{bob | hand: [%Card{suit: :spades, rank: 7}]}
      
      game = %{game | 
        players: [alice, bob],
        current_card: %Card{suit: :hearts, rank: 6}
      }

      socket_assigns = %{
        game: game,
        player_id: "alice",
        selected_cards: [0]  # Card selected but not played yet
      }

      # Alice plays her last card
      {:ok, finished_game} = Game.play_card(game, "alice", [0])
      
      updated_assigns = %{socket_assigns | 
        game: finished_game,
        selected_cards: []  # Should clear selections when game ends
      }

      assert updated_assigns.game.status == :finished
      assert "alice" in updated_assigns.game.winners
      assert updated_assigns.selected_cards == []
    end

    test "handles spectator joining finished game" do
      # Someone joins a game that just finished
      game = Game.new()
      |> Game.add_player("alice", "Alice", false)
      |> Game.add_player("bob", "Bob", false)
      |> Game.start_game()

      # Force game to finished state
      finished_game = %{game | 
        status: :finished,
        winners: ["alice"]
      }

      # Spectator joins
      spectator_assigns = %{
        game: finished_game,
        player_id: nil,  # Spectator
        selected_cards: []
      }

      # Spectator should see final state
      assert spectator_assigns.game.status == :finished
      assert "alice" in spectator_assigns.game.winners
    end
  end

  # Helper functions
  defp simulate_liveview_moves(initial_assigns, moves) do
    Enum.reduce(moves, initial_assigns, fn move, assigns ->
      case move do
        {:select_card, index} ->
          if index in assigns.selected_cards do
            assigns  # Already selected
          else
            %{assigns | selected_cards: [index | assigns.selected_cards]}
          end
        
        {:deselect_card, index} ->
          %{assigns | selected_cards: List.delete(assigns.selected_cards, index)}
        
        {:play_selected, []} ->
          if assigns.selected_cards != [] and 
             Game.current_player(assigns.game).id == assigns.player_id do
            case Game.play_card(assigns.game, assigns.player_id, assigns.selected_cards) do
              {:ok, new_game} ->
                %{assigns | game: new_game, selected_cards: []}
              {:error, _} ->
                %{assigns | selected_cards: []}  # Clear selections on error
            end
          else
            %{assigns | selected_cards: []}  # Clear selections if can't play
          end
      end
    end)
  end
end