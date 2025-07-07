defmodule Rachel.Games.GameServer do
  @moduledoc """
  GenServer that manages the state of a single game session.
  This is the authoritative source of game state for multiplayer games.
  """
  use GenServer

  alias Phoenix.PubSub
  alias Rachel.Games.{Card, Game, Player}

  @max_players 8
  @min_players 2

  @type game_id :: String.t()
  @type player_id :: String.t()
  @type timer_ref :: reference() | nil
  @type state :: %{
          game: Game.t(),
          connected_players: %{player_id() => boolean()},
          player_monitors: %{pid() => player_id()},
          spectators: %{player_id() => %{name: String.t(), connected: boolean()}},
          host_id: player_id() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          started_at: DateTime.t() | nil,
          timeout: timeout(),
          timeout_ref: timer_ref(),
          ai_timer_ref: timer_ref(),
          disconnect_check_timers: %{player_id() => timer_ref()}
        }

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  @spec join_game(game_id(), player_id(), String.t()) :: {:ok, Game.t()} | {:error, atom()}
  def join_game(game_id, player_id, player_name) do
    GenServer.call(via_tuple(game_id), {:join_game, player_id, player_name})
  end

  @spec join_as_spectator(game_id(), player_id(), String.t()) ::
          {:ok, Game.t()} | {:error, atom()}
  def join_as_spectator(game_id, player_id, player_name) do
    GenServer.call(via_tuple(game_id), {:join_as_spectator, player_id, player_name})
  end

  @spec player_connected(game_id(), player_id(), pid()) :: :ok
  def player_connected(game_id, player_id, pid) do
    GenServer.cast(via_tuple(game_id), {:player_connected, player_id, pid})
  end

  @spec player_disconnected(game_id(), player_id()) :: :ok
  def player_disconnected(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:player_disconnected, player_id})
  end

  @spec leave_game(game_id(), player_id()) :: {:ok, Game.t()} | {:error, atom()}
  def leave_game(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:leave_game, player_id})
  end

  @spec start_game(game_id(), player_id()) :: {:ok, Game.t()} | {:error, atom()}
  def start_game(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:start_game, player_id})
  end

  @spec play_cards(game_id(), player_id(), [Card.t()]) :: {:ok, Game.t()} | {:error, atom()}
  def play_cards(game_id, player_id, cards) do
    GenServer.call(via_tuple(game_id), {:play_cards, player_id, cards})
  end

  @spec draw_card(game_id(), player_id()) :: {:ok, Game.t()} | {:error, atom()}
  def draw_card(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:draw_card, player_id})
  end

  @spec nominate_suit(game_id(), player_id(), Card.suit()) :: {:ok, Game.t()} | {:error, atom()}
  def nominate_suit(game_id, player_id, suit) do
    GenServer.call(via_tuple(game_id), {:nominate_suit, player_id, suit})
  end

  @spec get_state(game_id()) :: map() | nil
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  catch
    :exit, {:noproc, _} -> nil
    :exit, _ -> nil
  end

  @spec add_ai_player(game_id(), String.t()) :: {:ok, Game.t()} | {:error, atom()}
  def add_ai_player(game_id, name) do
    GenServer.call(via_tuple(game_id), {:add_ai_player, name})
  end

  # Test helper to set state directly
  @spec set_state(game_id(), Game.t()) :: :ok
  def set_state(game_id, game) do
    GenServer.call(via_tuple(game_id), {:set_state, game})
  end

  @spec reconnect_player(game_id(), player_id()) :: :ok
  def reconnect_player(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:reconnect_player, player_id})
  end

  @spec disconnect_player(game_id(), player_id()) :: :ok
  def disconnect_player(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:disconnect_player, player_id})
  end

  @spec stop(game_id()) :: :ok
  def stop(game_id) do
    GenServer.stop(via_tuple(game_id), :normal)
  end

  # Server Callbacks

  @impl true
  def init(opts) when is_list(opts) do
    game_id = Keyword.get(opts, :game_id)
    timeout = Keyword.get(opts, :timeout, :infinity)

    game = Game.new(game_id)

    # Enhanced state that tracks multiplayer-specific data
    timeout_ref =
      if timeout != :infinity do
        Process.send_after(self(), :timeout, timeout)
      else
        nil
      end

    initial_state = %{
      game: game,
      # player_id => true/false
      connected_players: %{},
      # pid => player_id
      player_monitors: %{},
      # spectator_id => %{name: name, connected: true/false}
      spectators: %{},
      # player_id of the game creator/host
      host_id: nil,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      # When the game actually started playing
      started_at: nil,
      timeout: timeout,
      timeout_ref: timeout_ref,
      # Track active timers to prevent duplicates
      ai_timer_ref: nil,
      disconnect_check_timers: %{}
    }

    {:ok, initial_state}
  end

  @impl true
  def init(game_id) when is_binary(game_id) do
    init(game_id: game_id)
  end

  @impl true
  def handle_call({:join_game, player_id, player_name}, _from, state) do
    case validate_join(state.game, player_id) do
      :ok ->
        new_game = Game.add_player(state.game, player_id, player_name, false)

        # First player becomes the host
        host_id = if state.host_id == nil, do: player_id, else: state.host_id

        new_state = %{
          state
          | game: new_game,
            connected_players: Map.put(state.connected_players, player_id, true),
            host_id: host_id,
            updated_at: DateTime.utc_now()
        }

        broadcast_game_update(new_state)
        {:reply, {:ok, new_state.game}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:join_as_spectator, spectator_id, spectator_name}, _from, state) do
    case validate_spectator_join(state, spectator_id) do
      :ok ->
        new_state = %{
          state
          | spectators:
              Map.put(state.spectators, spectator_id, %{
                name: spectator_name,
                connected: true
              }),
            updated_at: DateTime.utc_now()
        }

        broadcast_spectator_joined(new_state, spectator_id, spectator_name)
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

        new_state = %{
          state
          | game: new_game,
            connected_players: Map.delete(state.connected_players, player_id),
            updated_at: DateTime.utc_now()
        }

        broadcast_game_update(new_state)
        {:reply, {:ok, new_state.game}, new_state}

      :playing ->
        # Convert to AI player during game
        new_players = convert_player_to_ai(state.game.players, player_id)
        new_game = %{state.game | players: new_players}

        new_state = %{
          state
          | game: new_game,
            connected_players: Map.put(state.connected_players, player_id, false),
            updated_at: DateTime.utc_now()
        }

        broadcast_game_update(new_state)

        # Schedule AI turn if it's their turn
        current_player = Enum.at(new_game.players, new_game.current_player_index)

        final_state =
          if current_player && current_player.id == player_id do
            # Cancel any existing AI timer first
            new_state = cancel_ai_timer(new_state)
            ai_ref = Process.send_after(self(), :ai_turn, 1000)
            %{new_state | ai_timer_ref: ai_ref}
          else
            new_state
          end

        {:reply, {:ok, final_state.game}, final_state}

      _ ->
        {:reply, {:error, :game_finished}, state}
    end
  end

  @impl true
  def handle_call({:start_game, player_id}, _from, state) do
    if state.host_id != player_id do
      {:reply, {:error, :not_host}, state}
    else
      execute_game_start(state)
    end
  end

  @impl true
  def handle_call({:play_cards, player_id, cards}, _from, state) do
    case validate_play_cards_request(state, player_id, cards) do
      {:ok, _player, card_indices} ->
        execute_play_cards_request(state, player_id, cards, card_indices)

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:draw_card, player_id}, _from, state) do
    case Game.draw_card(state.game, player_id) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
        broadcast_card_drawn(new_state, player_id)

        # Check if game just finished and record stats
        if state.game.status != :finished and new_game.status == :finished do
          record_game_stats(new_state)
        end

        # Schedule AI turn if next player is AI
        final_state = schedule_ai_turn_if_needed(new_state)

        {:reply, {:ok, final_state.game}, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:nominate_suit, player_id, suit}, _from, state) do
    case Game.nominate_suit(state.game, player_id, suit) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
        broadcast_suit_nominated(new_state, player_id, suit)

        # Schedule AI turn if next player is AI
        final_state = schedule_ai_turn_if_needed(new_state)

        {:reply, {:ok, final_state.game}, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Return a combined state for compatibility with tests
    combined_state =
      Map.merge(state.game, %{
        id: state.game.id,
        status: state.game.status,
        host_id: state.host_id,
        players:
          Enum.map(state.game.players, fn p ->
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
        current_card: state.game.current_card,
        spectators: state.spectators
      })

    # Reset timeout on activity
    new_state = reset_timeout(state)
    {:reply, combined_state, new_state}
  end

  @impl true
  def handle_call({:reconnect_player, player_id}, _from, state) do
    # Cancel any pending disconnect check timer
    state = cancel_disconnect_timer(state, player_id)

    new_state = %{
      state
      | connected_players: Map.put(state.connected_players, player_id, true),
        updated_at: DateTime.utc_now()
    }

    broadcast_player_reconnected(new_state, player_id)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:disconnect_player, player_id}, _from, state) do
    new_state = %{
      state
      | connected_players: Map.put(state.connected_players, player_id, false),
        updated_at: DateTime.utc_now()
    }

    broadcast_player_disconnected(new_state, player_id)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:add_ai_player, name}, _from, state) do
    if length(state.game.players) < @max_players and state.game.status == :waiting do
      ai_id = "ai-#{System.unique_integer()}"
      ai_player = Player.new(ai_id, name, is_ai: true, connected: true)

      new_players = state.game.players ++ [ai_player]
      new_game = %{state.game | players: new_players}

      new_state = %{
        state
        | game: new_game,
          connected_players: Map.put(state.connected_players, ai_id, true),
          updated_at: DateTime.utc_now()
      }

      broadcast_game_update(new_state)
      {:reply, {:ok, new_state.game}, new_state}
    else
      {:reply, {:error, :cannot_add_ai}, state}
    end
  end

  @impl true
  def handle_call({:set_state, game}, _from, state) do
    new_state = %{state | game: game, updated_at: DateTime.utc_now()}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:player_connected, player_id, pid}, state) do
    # Monitor the player's process
    Process.monitor(pid)

    new_state = %{
      state
      | connected_players: Map.put(state.connected_players, player_id, true),
        player_monitors: Map.put(state.player_monitors, pid, player_id),
        updated_at: DateTime.utc_now()
    }

    broadcast_player_reconnected(new_state, player_id)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:player_disconnected, player_id}, state) do
    new_state = %{
      state
      | connected_players: Map.put(state.connected_players, player_id, false),
        updated_at: DateTime.utc_now()
    }

    broadcast_player_disconnected(new_state, player_id)

    # Convert to AI if it's their turn and they disconnected
    current_player = Enum.at(state.game.players, state.game.current_player_index)

    final_state =
      if current_player && current_player.id == player_id && state.game.status == :playing do
        # Give them 5 seconds to reconnect
        # Cancel any existing AI timer first
        state_with_cancelled_timer = cancel_ai_timer(new_state)
        ai_ref = Process.send_after(self(), :ai_turn, 5000)
        %{state_with_cancelled_timer | ai_timer_ref: ai_ref}
      else
        new_state
      end

    {:noreply, final_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # A player process died - mark them as disconnected
    case Map.get(state.player_monitors, pid) do
      nil ->
        {:noreply, state}

      player_id ->
        new_state = %{
          state
          | connected_players: Map.put(state.connected_players, player_id, false),
            player_monitors: Map.delete(state.player_monitors, pid),
            updated_at: DateTime.utc_now()
        }

        broadcast_player_disconnected(new_state, player_id)

        # Give them time to reconnect before converting to AI
        current_player = Enum.at(state.game.players, state.game.current_player_index)

        final_state =
          if current_player && current_player.id == player_id && state.game.status == :playing do
            # 10 second grace period
            # Cancel any existing timer for this player
            state_with_cancelled = cancel_disconnect_timer(new_state, player_id)

            timer_ref =
              Process.send_after(self(), {:check_disconnected_player, player_id}, 10_000)

            put_in(state_with_cancelled.disconnect_check_timers[player_id], timer_ref)
          else
            new_state
          end

        {:noreply, final_state}
    end
  end

  @impl true
  def handle_info({:check_disconnected_player, player_id}, state) do
    # Remove timer from tracking since it fired
    state = %{
      state
      | disconnect_check_timers: Map.delete(state.disconnect_check_timers, player_id)
    }

    # Check if player is still disconnected after grace period
    if Map.get(state.connected_players, player_id) == false && state.game.status == :playing do
      # Convert to AI
      new_players = convert_player_to_ai(state.game.players, player_id)
      new_game = %{state.game | players: new_players}
      new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}

      broadcast_game_update(new_state)

      # If it's their turn, trigger AI move
      current_player = Enum.at(new_game.players, new_game.current_player_index)

      final_state =
        if current_player && current_player.id == player_id do
          # Cancel any existing AI timer first
          new_state = cancel_ai_timer(new_state)
          ai_ref = Process.send_after(self(), :ai_turn, 1000)
          %{new_state | ai_timer_ref: ai_ref}
        else
          new_state
        end

      {:noreply, final_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:ai_turn, state) do
    if should_process_ai_turn?(state) do
      {:noreply, process_ai_turn(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:ai_timeout, state) do
    if should_process_ai_turn?(state) do
      {:noreply, process_ai_turn(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  # AI-related private functions

  defp should_process_ai_turn?(state) do
    state.game.status == :playing &&
      current_player_is_ai?(state) &&
      current_player_connected?(state)
  end

  defp current_player_is_ai?(state) do
    case Enum.at(state.game.players, state.game.current_player_index) do
      nil -> false
      player -> player.is_ai
    end
  end

  defp current_player_connected?(state) do
    case Enum.at(state.game.players, state.game.current_player_index) do
      nil -> false
      player -> Map.get(state.connected_players, player.id, false) || player.is_ai
    end
  end

  defp process_ai_turn(state) do
    current_player = Enum.at(state.game.players, state.game.current_player_index)
    ai_decision = Rachel.Games.AIPlayer.make_move(state.game, current_player.id)

    case ai_decision do
      {:play, card_indices} -> handle_ai_play(state, current_player.id, card_indices)
      {:draw, _} -> handle_ai_draw(state, current_player.id)
      {:nominate, suit} -> handle_ai_nominate(state, current_player.id, suit)
      _ -> state
    end
  end

  defp handle_ai_play(state, player_id, card_indices) do
    case Game.play_card(state.game, player_id, card_indices) do
      {:ok, new_game} ->
        handle_successful_ai_play(state, new_game, player_id, card_indices)

      _ ->
        state
    end
  end

  defp handle_successful_ai_play(state, new_game, player_id, card_indices) do
    new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}

    # Get played cards for broadcast
    player = Enum.find(state.game.players, &(&1.id == player_id))
    # Handle both single index and list of indices
    indices_list = if is_list(card_indices), do: card_indices, else: [card_indices]
    played_cards = Enum.map(indices_list, fn idx -> Enum.at(player.hand, idx) end)

    broadcast_cards_played(new_state, player_id, played_cards)

    # Check for winner
    if player_id in new_game.winners do
      broadcast_winner(new_state, player_id)
    end

    # Check if game just finished
    if state.game.status != :finished and new_game.status == :finished do
      record_game_stats(new_state)
    end

    schedule_ai_turn_if_needed(new_state)
  end

  defp handle_ai_draw(state, player_id) do
    case Game.draw_card(state.game, player_id) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
        broadcast_card_drawn(new_state, player_id)

        if state.game.status != :finished and new_game.status == :finished do
          record_game_stats(new_state)
        end

        schedule_ai_turn_if_needed(new_state)

      _ ->
        state
    end
  end

  defp handle_ai_nominate(state, player_id, suit) do
    case Game.nominate_suit(state.game, player_id, suit) do
      {:ok, new_game} ->
        new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
        broadcast_suit_nominated(new_state, player_id, suit)
        schedule_ai_turn_if_needed(new_state)

      _ ->
        state
    end
  end

  # Helper Functions

  defp via_tuple(game_id) do
    {:via, Registry, {Rachel.GameRegistry, game_id}}
  end

  defp reset_timeout(state) do
    # Only handle timeout if state has timeout field
    if Map.has_key?(state, :timeout) and state.timeout != :infinity do
      # Cancel previous timeout if it exists
      if Map.get(state, :timeout_ref) do
        Process.cancel_timer(state.timeout_ref)
      end

      # Set new timeout
      new_timeout_ref = Process.send_after(self(), :timeout, state.timeout)
      %{state | updated_at: DateTime.utc_now(), timeout_ref: new_timeout_ref}
    else
      %{state | updated_at: DateTime.utc_now()}
    end
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

  defp validate_spectator_join(state, spectator_id) do
    cond do
      state.game.status == :waiting -> {:error, :game_not_started}
      Map.has_key?(state.spectators, spectator_id) -> {:error, :already_spectating}
      Enum.any?(state.game.players, &(&1.id == spectator_id)) -> {:error, :already_playing}
      true -> :ok
    end
  end

  defp get_current_player_id(game) do
    current_player = Enum.at(game.players, game.current_player_index)
    current_player && current_player.id
  end

  defp schedule_ai_turn_if_needed(state) do
    # Cancel any existing AI timer first
    state = cancel_ai_timer(state)

    current_player = Enum.at(state.game.players, state.game.current_player_index)

    if current_player && current_player.is_ai do
      ref = Process.send_after(self(), :ai_turn, 1500)
      %{state | ai_timer_ref: ref}
    else
      state
    end
  end

  # Stats recording

  defp record_game_stats(state) do
    if state.started_at do
      _ended_at = DateTime.utc_now()
      game_id = state.game.id

      # In test environment, skip stats recording to avoid database ownership issues
      # Tests can explicitly test stats recording if needed
      if Application.get_env(:rachel, :env) == :test do
        :ok
      else
        # In production, record stats asynchronously to avoid blocking the game
        Task.start(fn ->
          try do
            # Game recording removed for simplicity
          rescue
            error ->
              # Log error but don't crash the game server
              require Logger
              Logger.error("Failed to record game stats for game #{game_id}: #{inspect(error)}")
          end
        end)
      end
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
    player = Enum.find(state.game.players, &(&1.id == player_id))
    player_name = if player, do: player.name, else: "Unknown"

    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:cards_played,
       %{player_id: player_id, player_name: player_name, cards: cards, game: state.game}}
    )
  end

  defp broadcast_card_drawn(state, player_id) do
    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:card_drawn, %{player_id: player_id, game: state.game}}
    )
  end

  defp broadcast_winner(state, player_id) do
    player = Enum.find(state.game.players, &(&1.id == player_id))
    player_name = if player, do: player.name, else: "Unknown"
    # Position is 1-based index in the winners list
    position =
      case Enum.find_index(state.game.winners, &(&1 == player_id)) do
        # New winner
        nil -> length(state.game.winners) + 1
        # Already in list
        index -> index + 1
      end

    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:player_won, %{player_id: player_id, player_name: player_name, position: position}}
    )
  end

  defp broadcast_player_reconnected(state, player_id) do
    player = Enum.find(state.game.players, &(&1.id == player_id))
    player_name = if player, do: player.name, else: "Unknown"

    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:player_reconnected, %{player_id: player_id, player_name: player_name}}
    )
  end

  defp broadcast_suit_nominated(state, player_id, suit) do
    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:suit_nominated, %{player_id: player_id, suit: suit, game: state.game}}
    )
  end

  defp broadcast_player_disconnected(state, player_id) do
    player = Enum.find(state.game.players, &(&1.id == player_id))
    player_name = if player, do: player.name, else: "Unknown"

    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:player_disconnected, %{player_id: player_id, player_name: player_name}}
    )
  end

  defp broadcast_spectator_joined(state, spectator_id, spectator_name) do
    PubSub.broadcast(
      Rachel.PubSub,
      "game:#{state.game.id}",
      {:spectator_joined,
       %{spectator_id: spectator_id, spectator_name: spectator_name, game: state.game}}
    )
  end

  defp validate_play_cards_request(state, player_id, cards) do
    case Enum.find(state.game.players, &(&1.id == player_id)) do
      nil ->
        {:error, :player_not_found}

      player ->
        card_indices =
          cards
          |> Enum.map(fn card -> Enum.find_index(player.hand, &(&1 == card)) end)
          |> Enum.reject(&is_nil/1)

        if length(card_indices) == length(cards) do
          {:ok, player, card_indices}
        else
          {:error, :cards_not_in_hand}
        end
    end
  end

  defp execute_play_cards_request(state, player_id, cards, card_indices) do
    case Game.play_card(state.game, player_id, card_indices) do
      {:ok, new_game} ->
        new_state = process_successful_play(state, new_game, player_id, cards)
        {:reply, {:ok, new_state.game}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp process_successful_play(state, new_game, player_id, cards) do
    new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
    broadcast_cards_played(new_state, player_id, cards)

    # Check for winner
    if player_id in new_game.winners do
      broadcast_winner(new_state, player_id)
    end

    # Check if game just finished and record stats
    if state.game.status != :finished and new_game.status == :finished do
      record_game_stats(new_state)
    end

    # Schedule AI turn if next player is AI
    schedule_ai_turn_if_needed(new_state)
  end

  defp execute_game_start(state) do
    case validate_start(state.game) do
      :ok ->
        new_game = Game.start_game(state.game)
        started_at = DateTime.utc_now()
        new_state = %{state | game: new_game, updated_at: started_at, started_at: started_at}

        broadcast_game_started(new_state)
        final_state = schedule_ai_turn_if_needed(new_state)

        {:reply, {:ok, final_state.game}, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp convert_player_to_ai(players, player_id) do
    Enum.map(players, fn player ->
      if player.id == player_id do
        %{player | is_ai: true}
      else
        player
      end
    end)
  end

  defp cancel_ai_timer(state) do
    if state.ai_timer_ref do
      Process.cancel_timer(state.ai_timer_ref)
    end

    %{state | ai_timer_ref: nil}
  end

  defp cancel_disconnect_timer(state, player_id) do
    case Map.get(state.disconnect_check_timers, player_id) do
      nil ->
        state

      timer_ref ->
        Process.cancel_timer(timer_ref)
        %{state | disconnect_check_timers: Map.delete(state.disconnect_check_timers, player_id)}
    end
  end
end
