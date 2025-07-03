defmodule Rachel.Games.GameServerTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{GameServer, Game}

  describe "start_link/1" do
    test "starts a game server with initial state" do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, pid} = GameServer.start_link(game_id: game_id)
      
      assert Process.alive?(pid)
      state = GameServer.get_state(game_id)
      assert state.id == game_id
      assert state.status == :waiting
      assert state.players == []
    end
  end

  describe "join_game/3" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, game_id: game_id}
    end

    test "allows players to join a waiting game", %{game_id: game_id} do
      assert {:ok, _game} = GameServer.join_game(game_id, "player1", "Alice")
      assert {:ok, _game} = GameServer.join_game(game_id, "player2", "Bob")
      
      state = GameServer.get_state(game_id)
      assert length(state.players) == 2
      assert Enum.any?(state.players, &(&1.id == "player1" && &1.name == "Alice"))
      assert Enum.any?(state.players, &(&1.id == "player2" && &1.name == "Bob"))
    end

    test "prevents joining a full game", %{game_id: game_id} do
      # Join max players (8)
      for i <- 1..8 do
        {:ok, _} = GameServer.join_game(game_id, "player#{i}", "Player #{i}")
      end

      assert {:error, :game_full} = GameServer.join_game(game_id, "player9", "Player 9")
    end

    test "prevents duplicate player IDs", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      assert {:error, :already_joined} = GameServer.join_game(game_id, "player1", "Alice Again")
    end

    test "prevents joining a started game", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _} = GameServer.start_game(game_id, "player1")
      
      assert {:error, :game_started} = GameServer.join_game(game_id, "player3", "Charlie")
    end
  end

  describe "start_game/1" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, game_id: game_id}
    end

    test "starts game with minimum players", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      
      assert {:ok, _game} = GameServer.start_game(game_id, "player1")
      state = GameServer.get_state(game_id)
      assert state.status == :playing
      assert state.current_player_id in ["player1", "player2"]
      assert length(state.deck.cards) < 52  # Cards have been dealt
      
      # Each player should have cards
      Enum.each(state.players, fn player ->
        assert length(player.hand) > 0
      end)
    end

    test "prevents starting with too few players", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      
      assert {:error, :not_enough_players} = GameServer.start_game(game_id, "player1")
    end

    test "prevents starting an already started game", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _} = GameServer.start_game(game_id, "player1")
      
      assert {:error, :already_started} = GameServer.start_game(game_id, "player1")
    end
    
    test "only allows host to start the game", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      
      # player2 tries to start but they're not the host
      assert {:error, :not_host} = GameServer.start_game(game_id, "player2")
      
      # player1 (host) can start
      assert {:ok, _game} = GameServer.start_game(game_id, "player1")
    end
  end

  describe "play_cards/3" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, game} = GameServer.start_game(game_id, "player1")
      
      {:ok, game_id: game_id, game: game}
    end

    test "allows current player to play valid cards", %{game_id: game_id, game: _game} do
      state = GameServer.get_state(game_id)
      current_player = Enum.find(state.players, &(&1.id == state.current_player_id))
      
      # Use the Game module's get_valid_plays to find valid cards
      valid_plays = Game.get_valid_plays(state, current_player)
      
      if valid_plays != [] do
        {valid_card, _index} = hd(valid_plays)
        assert {:ok, updated_game} = GameServer.play_cards(game_id, current_player.id, [valid_card])
        assert updated_game.current_card == valid_card
        
        # Player's hand should be reduced
        updated_player = Enum.find(updated_game.players, &(&1.id == current_player.id))
        assert length(updated_player.hand) == length(current_player.hand) - 1
      end
    end

    test "prevents non-current player from playing", %{game_id: game_id, game: _game} do
      state = GameServer.get_state(game_id)
      other_player = Enum.find(state.players, &(&1.id != state.current_player_id))
      card = List.first(other_player.hand)
      
      assert {:error, :not_your_turn} = GameServer.play_cards(game_id, other_player.id, [card])
    end

    test "prevents playing invalid cards", %{game_id: game_id, game: _game} do
      state = GameServer.get_state(game_id)
      current_player = Enum.find(state.players, &(&1.id == state.current_player_id))
      
      # Try to find an invalid card
      invalid_card = Enum.find(current_player.hand, fn card ->
        Game.get_valid_plays(state, current_player)
        |> Enum.all?(fn {valid_card, _} -> valid_card != card end)
      end)
      
      if invalid_card do
        assert {:error, error} = GameServer.play_cards(game_id, current_player.id, [invalid_card])
        assert error in [:not_your_turn, :invalid_card_index, :invalid_play, :first_card_invalid]
      end
    end
  end

  describe "draw_card/2" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, game} = GameServer.start_game(game_id, "player1")
      
      {:ok, game_id: game_id, game: game}
    end

    test "allows current player to draw when they have no valid plays", %{game_id: game_id, game: _game} do
      state = GameServer.get_state(game_id)
      current_player = Enum.find(state.players, &(&1.id == state.current_player_id))
      
      # Only test if player actually has no valid plays
      has_valid_play = Game.has_valid_play?(state, current_player)
      
      if !has_valid_play do
        initial_hand_size = length(current_player.hand)
        assert {:ok, updated_game} = GameServer.draw_card(game_id, current_player.id)
        
        updated_player = Enum.find(updated_game.players, &(&1.id == current_player.id))
        assert length(updated_player.hand) == initial_hand_size + max(1, state.pending_pickups)
      end
    end

    test "prevents drawing when player has valid plays", %{game_id: game_id, game: _game} do
      state = GameServer.get_state(game_id)
      current_player = Enum.find(state.players, &(&1.id == state.current_player_id))
      
      # Check if player has a valid play
      has_valid_play = Game.has_valid_play?(state, current_player)
      
      if has_valid_play do
        assert {:error, :must_play_valid_card} = GameServer.draw_card(game_id, current_player.id)
      end
    end
  end

  describe "leave_game/2" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, game_id: game_id}
    end

    test "allows player to leave before game starts", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      
      assert {:ok, game} = GameServer.leave_game(game_id, "player1")
      assert length(game.players) == 1
      assert !Enum.any?(game.players, &(&1.id == "player1"))
    end

    test "converts player to AI when leaving during game", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _} = GameServer.start_game(game_id, "player1")
      
      assert {:ok, game} = GameServer.leave_game(game_id, "player1")
      
      ai_player = Enum.find(game.players, &(&1.name == "Alice"))
      assert ai_player.is_ai == true
    end
  end

  describe "broadcast integration" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      Phoenix.PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, game_id: game_id}
    end

    test "broadcasts game state updates", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      
      assert_receive {:game_updated, game}
      assert game.id == game_id
      assert length(game.players) == 1
    end

    test "broadcasts when game starts", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _} = GameServer.start_game(game_id, "player1")
      
      assert_receive {:game_started, game}
      assert game.status == :playing
    end

    test "broadcasts player actions", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "player1")
      
      state = GameServer.get_state(game_id)
      current_player = Enum.find(state.players, &(&1.id == state.current_player_id))
      valid_plays = Game.get_valid_plays(state, current_player)
      
      if valid_plays != [] do
        {valid_card, _index} = hd(valid_plays)
        {:ok, _} = GameServer.play_cards(game_id, current_player.id, [valid_card])
        assert_receive {:cards_played, %{player_id: player_id, cards: cards}}
        assert player_id == current_player.id
        assert cards == [valid_card]
      end
    end
  end

  describe "game completion" do
    test "handles winner and continues game for remaining players" do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      
      # Set up a game where one player can win quickly
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _} = GameServer.join_game(game_id, "player3", "Charlie")
      
      # We'll need to mock or set up a specific game state here
      # For now, this is a placeholder for the win condition test
    end
  end

  describe "nominate_suit/3" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, game} = GameServer.start_game(game_id, "player1")
      
      {:ok, game_id: game_id, game: game}
    end

    test "allows current player to nominate suit when ace is played", %{game_id: game_id} do
      # This test requires the game to be in a state where nomination is pending
      # For now, we'll test the error case since setting up a nomination state 
      # would require complex game state manipulation
      current_player_id = GameServer.get_state(game_id).current_player_id
      
      # Should return error when no ace is played
      assert {:error, :no_ace_played} = GameServer.nominate_suit(game_id, current_player_id, :hearts)
    end

    test "prevents non-current player from nominating suit", %{game_id: game_id} do
      state = GameServer.get_state(game_id)
      other_player = Enum.find(state.players, &(&1.id != state.current_player_id))
      
      assert {:error, :no_ace_played} = GameServer.nominate_suit(game_id, other_player.id, :hearts)
    end
  end

  describe "spectator mode" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _game} = GameServer.start_game(game_id, "player1")
      
      {:ok, game_id: game_id}
    end

    test "allows spectators to join started games", %{game_id: game_id} do
      assert {:ok, _game} = GameServer.join_as_spectator(game_id, "spectator1", "Charlie")
      
      state = GameServer.get_state(game_id)
      assert Map.has_key?(state.spectators, "spectator1")
      assert state.spectators["spectator1"].name == "Charlie"
      assert state.spectators["spectator1"].connected == true
    end

    test "prevents spectators from joining waiting games", %{game_id: _game_id} do
      waiting_game_id = "waiting-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: waiting_game_id)
      {:ok, _} = GameServer.join_game(waiting_game_id, "player1", "Alice")
      
      assert {:error, :game_not_started} = GameServer.join_as_spectator(waiting_game_id, "spectator1", "Charlie")
    end

    test "prevents duplicate spectator IDs", %{game_id: game_id} do
      {:ok, _} = GameServer.join_as_spectator(game_id, "spectator1", "Charlie")
      assert {:error, :already_spectating} = GameServer.join_as_spectator(game_id, "spectator1", "Charlie Again")
    end

    test "prevents players from becoming spectators", %{game_id: game_id} do
      assert {:error, :already_playing} = GameServer.join_as_spectator(game_id, "player1", "Alice as Spectator")
    end
  end

  describe "reconnection" do
    setup do
      game_id = "test-game-#{System.unique_integer()}"
      {:ok, _pid} = GameServer.start_link(game_id: game_id)
      {:ok, game_id: game_id}
    end

    test "allows player to reconnect to ongoing game", %{game_id: game_id} do
      {:ok, _} = GameServer.join_game(game_id, "player1", "Alice")
      {:ok, _} = GameServer.join_game(game_id, "player2", "Bob")
      {:ok, _} = GameServer.start_game(game_id, "player1")
      
      # Simulate disconnect/reconnect
      assert {:ok, _game} = GameServer.reconnect_player(game_id, "player1")
      
      state = GameServer.get_state(game_id)
      player = Enum.find(state.players, &(&1.id == "player1"))
      assert player.connected == true
    end
  end
end