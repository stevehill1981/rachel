defmodule Rachel.Games.GameServerAITest do
  use ExUnit.Case, async: false

  alias Rachel.Games.{GameServer, Game, Player, Card, Deck}
  alias Test.{GameServerBuilder, GameBuilder}

  setup do
    game_id = "test-game-#{System.unique_integer()}"
    
    on_exit(fn ->
      # Cleanup game if it exists
      case GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}}) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 5000)
      end
    end)
    
    {:ok, game_id: game_id}
  end

  describe "AI turn scheduling" do
    test "schedules AI turn when AI player is current", %{game_id: _game_id} do
      # Use GameServerBuilder for cleaner setup
      {game_id, pid} = GameServerBuilder.start_server()
        |> GameServerBuilder.with_cleanup()
        |> GameServerBuilder.add_player("human-1", "Human Player", false)
        |> GameServerBuilder.add_player("ai-1", "AI Player", true)
        |> GameServerBuilder.start_game("human-1")
      
      # Get initial state
      initial_game = GameServerBuilder.get_state({game_id, pid})
      
      # Ensure AI player is current (manually set if needed)
      ai_player_index = Enum.find_index(initial_game.players, & &1.is_ai)
      refute is_nil(ai_player_index), "Should have an AI player"
      
      # Set game state so AI is current player
      game_with_ai_turn = %{initial_game | current_player_index: ai_player_index}
      GameServer.set_state(game_id, game_with_ai_turn)
      
      # Get the AI player info
      ai_player = Enum.at(game_with_ai_turn.players, ai_player_index)
      assert ai_player.is_ai == true
      
      # Manually trigger AI turn since we bypassed normal game flow
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait for AI to make a move
      Process.sleep(1000)
      
      # Get updated game state
      updated_game = GameServerBuilder.get_state({game_id, pid})
      
      # AI should have either played a card or drawn (hand count should change OR turn should advance)
      updated_ai_player = Enum.at(updated_game.players, ai_player_index)
      
      # Either the turn advanced (AI played) or AI drew cards (hand size increased)
      turn_advanced = updated_game.current_player_index != ai_player_index
      hand_size_changed = length(updated_ai_player.hand) != length(ai_player.hand)
      
      assert turn_advanced or hand_size_changed, 
        "AI should have either played a card (advancing turn) or drawn cards (changing hand size)"
    end

    test "schedules AI turn after human plays", %{game_id: _game_id} do
      # Use GameServerBuilder for cleaner setup
      {game_id, pid} = GameServerBuilder.start_server()
        |> GameServerBuilder.with_cleanup()
        |> GameServerBuilder.add_player("human-1", "Human Player", false)
        |> GameServerBuilder.add_player("ai-1", "AI Player", true)
        |> GameServerBuilder.start_game("human-1")
      
      # Get the initial game state
      initial_game = GameServerBuilder.get_state({game_id, pid})
      
      # Ensure human is first player
      human_player = Enum.at(initial_game.players, 0)
      assert human_player.is_ai == false
      
      # Make human play a valid card (instead of trying to draw)
      # Find a card the human can play
      valid_card = Enum.find(human_player.hand, fn card ->
        card.suit == initial_game.current_card.suit || 
        card.rank == initial_game.current_card.rank ||
        card.rank == :ace
      end)
      
      # Human plays a card to pass turn to AI
      if valid_card do
        {:ok, _game} = GameServer.play_cards(game_id, "human-1", [valid_card])
      else
        # If no valid card, set up the game so human can draw
        game_with_no_valid_plays = GameBuilder.set_current_card(initial_game, 
          GameBuilder.card({:diamonds, :king})) # Something human can't match
        GameServer.set_state(game_id, game_with_no_valid_plays)
        {:ok, _game} = GameServer.draw_card(game_id, "human-1")
      end
      
      # Wait for AI turn
      Process.sleep(2000)
      
      # Get updated state
      updated_game = GameServer.get_state(game_id)
      
      # Should be back to human's turn (index 0) after AI played
      assert updated_game.current_player_index == 0
    end

    test "AI plays valid cards when available", %{game_id: game_id} do
      # Start game server
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      
      # Create controlled game state
      players = [
        %Player{
          id: "ai-1",
          name: "AI Player",
          is_ai: true,
          hand: [
            %Card{suit: :hearts, rank: :seven},
            %Card{suit: :clubs, rank: :king},
            %Card{suit: :diamonds, rank: :ace}
          ],
          connected: true,
          has_drawn: false
        },
        %Player{
          id: "human-1", 
          name: "Human",
          is_ai: false,
          hand: [
            %Card{suit: :hearts, rank: :eight},
            %Card{suit: :spades, rank: :queen}
          ],
          connected: true,
          has_drawn: false
        }
      ]
      
      game = %Game{
        id: game_id,
        players: players,
        current_player_index: 0, # AI's turn
        current_card: %Card{suit: :hearts, rank: :six}, # AI can play seven of hearts
        deck: %Deck{cards: [], discarded: []}, # Empty deck for testing
        status: :playing,
        direction: :clockwise,
        pending_pickups: 0,
        pending_pickup_type: nil,
        nominated_suit: nil,
        winners: []
      }
      
      # Set initial state
      GameServer.set_state(game_id, game)
      
      # Trigger AI turn
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait for AI to process
      Process.sleep(500)
      
      # Get updated state
      updated_game = GameServer.get_state(game_id)
      
      # AI should have played the seven of hearts
      assert updated_game.current_card == %Card{suit: :hearts, rank: :seven}
      assert length(Enum.at(updated_game.players, 0).hand) == 2
    end

    test "AI draws card when no valid plays", %{game_id: _game_id} do
      # Use GameBuilder and GameServerBuilder for cleaner setup
      {game_id, pid} = GameServerBuilder.start_server()
        |> GameServerBuilder.with_cleanup()
      
      # Create a game state where AI has no valid plays using GameBuilder
      game = GameBuilder.two_player_game("ai-1", "human-1")
        |> GameBuilder.set_current_player("ai-1")
        |> GameBuilder.set_current_card(GameBuilder.card({:hearts, 6})) # AI can't play on this
        |> GameBuilder.give_cards("ai-1", [
          GameBuilder.card({:clubs, 7}),    # Can't play - wrong suit/rank
          GameBuilder.card({:diamonds, :king}) # Can't play - wrong suit/rank
        ])
        |> GameBuilder.give_cards("human-1", [
          GameBuilder.card({:hearts, 8})   # Human has a valid card
        ])
        # Make AI player actually AI
        |> (fn game ->
          players = Enum.map(game.players, fn player ->
            if player.id == "ai-1" do
              %{player | is_ai: true, name: "AI Player"}
            else
              %{player | name: "Human"}
            end
          end)
          %{game | players: players}
        end).()
      
      # Set the game state
      GameServerBuilder.set_game_state({game_id, pid}, game)
      
      # Get initial AI hand size
      initial_game = GameServerBuilder.get_state({game_id, pid})
      ai_player = Enum.find(initial_game.players, & &1.is_ai)
      initial_hand_size = length(ai_player.hand)
      
      # Trigger AI turn manually
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait for AI to process
      Process.sleep(500)
      
      # Get updated state
      updated_game = GameServerBuilder.get_state({game_id, pid})
      updated_ai_player = Enum.find(updated_game.players, & &1.is_ai)
      
      # AI should have drawn a card (hand size increased)
      assert length(updated_ai_player.hand) == initial_hand_size + 1,
        "AI should have drawn a card when no valid plays available"
    end

    test "AI nominates suit after playing ace", %{game_id: game_id} do
      # Start game server
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      
      # Create state where AI will play an ace
      players = [
        %Player{
          id: "ai-1",
          name: "AI Player",
          is_ai: true,
          hand: [
            %Card{suit: :hearts, rank: :ace}, # Will play this
            %Card{suit: :clubs, rank: :seven},
            %Card{suit: :clubs, rank: :king}  # Has more clubs
          ],
          connected: true,
          has_drawn: false
        },
        %Player{
          id: "human-1",
          name: "Human", 
          is_ai: false,
          hand: [%Card{suit: :diamonds, rank: :eight}],
          connected: true,
          has_drawn: false
        }
      ]
      
      game = %Game{
        id: game_id,
        players: players,
        current_player_index: 0,
        current_card: %Card{suit: :hearts, rank: :six},
        deck: %Deck{cards: [], discarded: []}, # Empty deck for testing
        status: :playing,
        direction: :clockwise,
        pending_pickups: 0,
        pending_pickup_type: nil,
        nominated_suit: nil,
        winners: []
      }
      
      # Set initial state
      GameServer.set_state(game_id, game)
      
      # Trigger AI turn
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait for AI to play ace
      Process.sleep(500)
      
      # Check ace was played
      mid_game = GameServer.get_state(game_id)
      assert mid_game.current_card == %Card{suit: :hearts, rank: :ace}
      assert mid_game.nominated_suit == :pending
      
      # Trigger AI nomination
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait for nomination
      Process.sleep(500)
      
      # Check suit was nominated (should pick clubs as AI has more)
      final_game = GameServer.get_state(game_id)
      assert final_game.nominated_suit == :clubs
    end
  end

  describe "AI turn error handling" do
    test "AI turn does nothing when not AI's turn", %{game_id: game_id} do
      # Start game server
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      
      # Join with human players only
      {:ok, _game} = GameServer.join_game(game_id, "human-1", "Human 1")
      {:ok, _game} = GameServer.join_game(game_id, "human-2", "Human 2")
      
      # Start game
      {:ok, game} = GameServer.start_game(game_id, "human-1")
      
      # Trigger AI turn when no AI players
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait a bit
      Process.sleep(500)
      
      # Game state should be unchanged
      updated_game = GameServer.get_state(game_id)
      assert updated_game.current_player_index == game.current_player_index
    end

    test "AI turn does nothing when game not playing", %{game_id: game_id} do
      # Start game server
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      
      # Join players but don't start
      {:ok, _game} = GameServer.join_game(game_id, "human-1", "Human")
      {:ok, game} = GameServer.add_ai_player(game_id, "AI Player")
      
      # Game should be in waiting status
      assert game.status == :waiting
      
      # Trigger AI turn
      game_pid = GenServer.whereis({:via, Registry, {Rachel.GameRegistry, game_id}})
      send(game_pid, :ai_turn)
      
      # Wait
      Process.sleep(500)
      
      # Game should still be waiting
      updated_game = GameServer.get_state(game_id)
      assert updated_game.status == :waiting
    end
  end

  describe "schedule_ai_turn_if_needed/1" do
    test "is called after game starts", %{game_id: game_id} do
      # Start game server
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      
      # Add AI first so AI goes first
      {:ok, _game} = GameServer.add_ai_player(game_id, "AI Player")
      {:ok, _game} = GameServer.join_game(game_id, "human-1", "Human")
      
      # Start game
      {:ok, game} = GameServer.start_game(game_id, "human-1")
      
      # If AI is first, wait and check that turn advanced
      if Enum.at(game.players, game.current_player_index).is_ai do
        Process.sleep(2000)
        updated_game = GameServer.get_state(game_id)
        # AI should have taken turn
        assert updated_game.current_player_index != game.current_player_index ||
               length(Enum.at(updated_game.players, 0).hand) != 7
      end
    end
  end
end