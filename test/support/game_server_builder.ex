defmodule Test.GameServerBuilder do
  @moduledoc """
  Test helpers for building GameServer scenarios.
  
  Example usage:
      {game_id, pid} = GameServerBuilder.start_server()
        |> GameServerBuilder.add_players(["alice", "bob"])
        |> GameServerBuilder.start_game("alice")
        |> GameServerBuilder.play_valid_card("alice")
  """
  
  alias Rachel.Games.{GameServer, Card}
  alias Test.GameBuilder
  
  @doc "Starts a new GameServer with unique ID and returns {game_id, pid}"
  def start_server(opts \\ []) do
    game_id = unique_game_id()
    timeout = Keyword.get(opts, :timeout, :infinity)
    {:ok, pid} = GameServer.start_link(game_id: game_id, timeout: timeout)
    {game_id, pid}
  end
  
  @doc "Adds multiple players to the game"
  def add_players({game_id, pid}, player_configs) when is_list(player_configs) do
    Enum.each(player_configs, fn
      {id, name, is_ai} ->
        if is_ai do
          GameServer.add_ai_player(game_id, name)
        else
          GameServer.join_game(game_id, id, name)
        end
      
      {id, name} ->
        GameServer.join_game(game_id, id, name)
        
      id when is_binary(id) ->
        GameServer.join_game(game_id, id, String.capitalize(id))
    end)
    
    {game_id, pid}
  end
  
  @doc "Adds a single player"
  def add_player({game_id, pid}, player_id, name \\ nil, is_ai \\ false) do
    name = name || String.capitalize(player_id)
    
    if is_ai do
      GameServer.add_ai_player(game_id, name)
    else
      GameServer.join_game(game_id, player_id, name)
    end
    
    {game_id, pid}
  end
  
  @doc "Starts the game with specified host"
  def start_game({game_id, pid}, host_id) do
    {:ok, _game} = GameServer.start_game(game_id, host_id)
    {game_id, pid}
  end
  
  @doc "Sets the internal game state directly (for testing)"
  def set_game_state({game_id, pid}, game) do
    :ok = GameServer.set_state(game_id, game)
    {game_id, pid}
  end
  
  @doc "Plays a valid card for the current player"
  def play_valid_card({game_id, pid}, player_id) do
    state = GameServer.get_state(game_id)
    player = Enum.find(state.players, &(&1.id == player_id))
    
    # Find a valid card to play
    valid_card = Enum.find(player.hand, fn card ->
      if state.current_card do
        card.suit == state.current_card.suit || 
        card.rank == state.current_card.rank ||
        card.rank == :ace
      else
        true # Any card if no current card
      end
    end)
    
    if valid_card do
      GameServer.play_cards(game_id, player_id, [valid_card])
    else
      # Force draw if no valid plays
      GameServer.draw_card(game_id, player_id)
    end
    
    {game_id, pid}
  end
  
  @doc "Plays specific cards"
  def play_cards({game_id, pid}, player_id, cards) do
    GameServer.play_cards(game_id, player_id, cards)
    {game_id, pid}
  end
  
  @doc "Makes a player draw a card"
  def draw_card({game_id, pid}, player_id) do
    GameServer.draw_card(game_id, player_id)
    {game_id, pid}
  end
  
  @doc "Disconnects a player"
  def disconnect_player({game_id, pid}, player_id) do
    GameServer.disconnect_player(game_id, player_id)
    {game_id, pid}
  end
  
  @doc "Reconnects a player"
  def reconnect_player({game_id, pid}, player_id) do
    GameServer.reconnect_player(game_id, player_id)
    {game_id, pid}
  end
  
  @doc "Gets the current game state"
  def get_state({game_id, _pid}) do
    GameServer.get_state(game_id)
  end
  
  @doc "Waits for an AI turn to complete (with timeout)"
  def wait_for_ai_turn({game_id, pid}, timeout \\ 2000) do
    # Wait a bit for AI to make its move
    Process.sleep(timeout)
    {game_id, pid}
  end
  
  @doc "Sets up a typical 2-player game ready to play"
  def typical_game(p1_id \\ "player1", p2_id \\ "player2") do
    start_server()
    |> add_players([p1_id, p2_id])
    |> start_game(p1_id)
  end
  
  @doc "Sets up a game with one human and one AI"
  def human_vs_ai_game(human_id \\ "human", ai_name \\ "Computer") do
    start_server()
    |> add_player(human_id)
    |> add_player("ai-1", ai_name, true)
    |> start_game(human_id)
  end
  
  @doc "Sets up a game scenario for testing reconnection"
  def reconnection_scenario(player_id \\ "player1") do
    start_server()
    |> add_players([player_id, "player2"])
    |> start_game(player_id)
    |> disconnect_player(player_id)
  end
  
  @doc "Sets up a game with timeout for testing cleanup"
  def timeout_game(timeout_ms \\ 100) do
    start_server(timeout: timeout_ms)
    |> add_players(["p1", "p2"])
  end
  
  @doc "Cleanup helper for tests"
  def cleanup({_game_id, pid}) do
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal, 1000)
    end
    :ok
  end
  
  @doc "Sets up proper test cleanup"
  def with_cleanup({game_id, pid} = server) do
    # Use ExUnit's on_exit for cleanup
    ExUnit.Callbacks.on_exit(fn ->
      cleanup(server)
    end)
    
    {game_id, pid}
  end
  
  # Private helpers
  
  defp unique_game_id do
    "test-#{System.unique_integer()}-#{System.system_time()}"
  end
end