defmodule Rachel.Games.GameServer do
  @moduledoc """
  GenServer that manages the state of a single game session.
  This is the authoritative source of game state for multiplayer games.
  """
  use GenServer

  alias Rachel.Games.{Game, Player}
  alias Phoenix.PubSub

  @max_players 8
  @min_players 2

  # Client API

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def join_game(game_id, player_id, player_name) do
    GenServer.call(via_tuple(game_id), {:join_game, player_id, player_name})
  end

  def leave_game(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:leave_game, player_id})
  end

  def start_game(game_id) do
    GenServer.call(via_tuple(game_id), :start_game)
  end

  def play_cards(game_id, player_id, cards) do
    GenServer.call(via_tuple(game_id), {:play_cards, player_id, cards})
  end

  def draw_card(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:draw_card, player_id})
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  def reconnect_player(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:reconnect_player, player_id})
  end

  # Server Callbacks

  @impl true
  def init(game_id) do
    game = Game.new(game_id)
    
    # Enhanced state that tracks multiplayer-specific data
    initial_state = %{
      game: game,
      connected_players: %{},  # player_id => true/false
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:join_game, player_id, player_name}, _from, state) do
    case validate_join(state.game, player_id) do
      :ok ->
        new_game = Game.add_player(state.game, player_id, player_name, false)
        
        new_state = %{state | 
          game: new_game,
          connected_players: Map.put(state.connected_players, player_id, true),
          updated_at: DateTime.utc_now()
        }

        broadcast_game_update(new_state)
        {:reply, {:ok, new_state.game}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:leave_game, player_id}, _from, state) do
    case state.game.status do
      :waiting ->
        # Remove player from waiting game
        new_players = Enum.reject(state.game.players, &(&1.id == player_id))
        new_game = %{state.game | players: new_players}
        new_state = %{state | 
          game: new_game,
          connected_players: Map.delete(state.connected_players, player_id),
          updated_at: DateTime.utc_now()
        }
        broadcast_game_update(new_state)
        {:reply, {:ok, new_state.game}, new_state}

      :playing ->
        # Convert to AI player during game
        new_players = Enum.map(state.game.players, fn player ->
          if player.id == player_id do
            %{player | is_ai: true}
          else
            player
          end
        end)
        new_game = %{state.game | players: new_players}
        new_state = %{state | 
          game: new_game,
          connected_players: Map.put(state.connected_players, player_id, false),
          updated_at: DateTime.utc_now()
        }
        broadcast_game_update(new_state)
        
        # Schedule AI turn if it's their turn
        current_player = Enum.at(new_game.players, new_game.current_player_index)
        if current_player && current_player.id == player_id do
          Process.send_after(self(), :ai_turn, 1000)
        end
        
        {:reply, {:ok, new_state.game}, new_state}

      _ ->
        {:reply, {:error, :game_finished}, state}
    end
  end

  @impl true
  def handle_call(:start_game, _from, state) do
    case validate_start(state.game) do
      :ok ->
        new_game = Game.start_game(state.game)
        new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
        
        broadcast_game_started(new_state)
        
        # Schedule AI turn if first player is AI
        current_player = Enum.at(new_game.players, new_game.current_player_index)
        if current_player && current_player.is_ai do
          Process.send_after(self(), :ai_turn, 1500)
        end
        
        {:reply, {:ok, new_state.game}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:play_cards, player_id, cards}, _from, state) do
    # Convert cards to indices
    player = Enum.find(state.game.players, &(&1.id == player_id))
    
    if player do
      card_indices = cards 
        |> Enum.map(fn card -> Enum.find_index(player.hand, &(&1 == card)) end)
        |> Enum.reject(&is_nil/1)
      
      if length(card_indices) == length(cards) do
        case Game.play_card(state.game, player_id, card_indices) do
          {:ok, new_game} ->
            new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
            broadcast_cards_played(new_state, player_id, cards)
            
            # Check for winner
            if player_id in new_game.winners do
              broadcast_winner(new_state, player_id)
            end
            
            # Schedule AI turn if next player is AI
            schedule_ai_turn_if_needed(new_state)
            
            {:reply, {:ok, new_state.game}, new_state}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      else
        {:reply, {:error, :cards_not_in_hand}, state}
      end
    else
      {:reply, {:error, :player_not_found}, state}
    end
  end

  @impl true
  def handle_call({:draw_card, player_id}, _from, state) do
    case Game.draw_card(state.game, player_id) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
        broadcast_card_drawn(new_state, player_id)
        
        # Schedule AI turn if next player is AI
        schedule_ai_turn_if_needed(new_state)
        
        {:reply, {:ok, new_state.game}, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Return a combined state for compatibility with tests
    combined_state = Map.merge(state.game, %{
      id: state.game.id,
      status: state.game.status,
      players: Enum.map(state.game.players, fn p ->
        %Player{
          id: p.id,
          name: p.name,
          hand: p.hand,
          is_ai: p.is_ai,
          connected: Map.get(state.connected_players, p.id, false),
          has_drawn: false
        }
      end),
      current_player_id: get_current_player_id(state.game),
      winner_ids: state.game.winners,
      deck: state.game.deck,
      current_card: state.game.current_card
    })
    
    {:reply, combined_state, state}
  end

  @impl true
  def handle_call({:reconnect_player, player_id}, _from, state) do
    new_state = %{state | 
      connected_players: Map.put(state.connected_players, player_id, true),
      updated_at: DateTime.utc_now()
    }
    
    broadcast_player_reconnected(new_state, player_id)
    {:reply, {:ok, new_state.game}, new_state}
  end

  @impl true
  def handle_info(:ai_turn, state) do
    if state.game.status == :playing do
      current_player = Enum.at(state.game.players, state.game.current_player_index)
      
      if current_player && current_player.is_ai do
        ai_decision = Rachel.Games.AIPlayer.make_move(state.game, current_player.id)
        
        case ai_decision do
          {:play, card_index} ->
            case Game.play_card(state.game, current_player.id, card_index) do
              {:ok, new_game} ->
                new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
                played_card = Enum.at(current_player.hand, card_index)
                broadcast_cards_played(new_state, current_player.id, [played_card])
                schedule_ai_turn_if_needed(new_state)
                {:noreply, new_state}
                
              _ ->
                {:noreply, state}
            end
            
          {:draw, _} ->
            case Game.draw_card(state.game, current_player.id) do
              {:ok, new_game} ->
                new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
                broadcast_card_drawn(new_state, current_player.id)
                schedule_ai_turn_if_needed(new_state)
                {:noreply, new_state}
                
              _ ->
                {:noreply, state}
            end
            
          {:nominate, suit} ->
            case Game.nominate_suit(state.game, current_player.id, suit) do
              {:ok, new_game} ->
                new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
                broadcast_suit_nominated(new_state, current_player.id, suit)
                schedule_ai_turn_if_needed(new_state)
                {:noreply, new_state}
                
              _ ->
                {:noreply, state}
            end
            
          _ ->
            {:noreply, state}
        end
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  # Helper Functions

  defp via_tuple(game_id) do
    {:via, Registry, {Rachel.GameRegistry, game_id}}
  end

  defp validate_join(game, player_id) do
    cond do
      game.status != :waiting -> {:error, :game_started}
      length(game.players) >= @max_players -> {:error, :game_full}
      Enum.any?(game.players, &(&1.id == player_id)) -> {:error, :already_joined}
      true -> :ok
    end
  end

  defp validate_start(game) do
    cond do
      game.status != :waiting -> {:error, :already_started}
      length(game.players) < @min_players -> {:error, :not_enough_players}
      true -> :ok
    end
  end

  defp get_current_player_id(game) do
    current_player = Enum.at(game.players, game.current_player_index)
    current_player && current_player.id
  end

  defp schedule_ai_turn_if_needed(state) do
    current_player = Enum.at(state.game.players, state.game.current_player_index)
    if current_player && current_player.is_ai do
      Process.send_after(self(), :ai_turn, 1500)
    end
  end

  # Broadcasting

  defp broadcast_game_update(state) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", {:game_updated, state.game})
  end

  defp broadcast_game_started(state) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", {:game_started, state.game})
  end

  defp broadcast_cards_played(state, player_id, cards) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", 
      {:cards_played, %{player_id: player_id, cards: cards, game: state.game}})
  end

  defp broadcast_card_drawn(state, player_id) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", 
      {:card_drawn, %{player_id: player_id, game: state.game}})
  end

  defp broadcast_winner(state, player_id) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", 
      {:player_won, %{player_id: player_id, game: state.game}})
  end

  defp broadcast_player_reconnected(state, player_id) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", 
      {:player_reconnected, %{player_id: player_id, game: state.game}})
  end

  defp broadcast_suit_nominated(state, player_id, suit) do
    PubSub.broadcast(Rachel.PubSub, "game:#{state.game.id}", 
      {:suit_nominated, %{player_id: player_id, suit: suit, game: state.game}})
  end
end