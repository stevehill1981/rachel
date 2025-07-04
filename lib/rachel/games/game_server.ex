defmodule Rachel.Games.GameServer do
  @moduledoc """
  GenServer that manages the state of a single game session.
  This is the authoritative source of game state for multiplayer games.
  """
  use GenServer

  alias Rachel.Games.{Game, Player}
  alias Rachel.Accounts.Stats, as: AccountsStats
  alias Phoenix.PubSub

  @max_players 8
  @min_players 2

  # Client API

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  def join_game(game_id, player_id, player_name) do
    GenServer.call(via_tuple(game_id), {:join_game, player_id, player_name})
  end

  def join_as_spectator(game_id, player_id, player_name) do
    GenServer.call(via_tuple(game_id), {:join_as_spectator, player_id, player_name})
  end

  def player_connected(game_id, player_id, pid) do
    GenServer.cast(via_tuple(game_id), {:player_connected, player_id, pid})
  end

  def player_disconnected(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:player_disconnected, player_id})
  end

  def leave_game(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:leave_game, player_id})
  end

  def start_game(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:start_game, player_id})
  end

  def play_cards(game_id, player_id, cards) do
    GenServer.call(via_tuple(game_id), {:play_cards, player_id, cards})
  end

  def draw_card(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:draw_card, player_id})
  end

  def nominate_suit(game_id, player_id, suit) do
    GenServer.call(via_tuple(game_id), {:nominate_suit, player_id, suit})
  end

  def get_state(game_id) do
    try do
      GenServer.call(via_tuple(game_id), :get_state)
    catch
      :exit, {:noproc, _} -> nil
      :exit, _ -> nil
    end
  end

  def add_ai_player(game_id, name) do
    GenServer.call(via_tuple(game_id), {:add_ai_player, name})
  end

  # Test helper to set state directly
  def set_state(game_id, game) do
    GenServer.call(via_tuple(game_id), {:set_state, game})
  end

  def reconnect_player(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:reconnect_player, player_id})
  end

  def disconnect_player(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:disconnect_player, player_id})
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
      timeout_ref: timeout_ref
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
        new_players =
          Enum.map(state.game.players, fn player ->
            if player.id == player_id do
              %{player | is_ai: true}
            else
              player
            end
          end)

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

        if current_player && current_player.id == player_id do
          Process.send_after(self(), :ai_turn, 1000)
        end

        {:reply, {:ok, new_state.game}, new_state}

      _ ->
        {:reply, {:error, :game_finished}, state}
    end
  end

  @impl true
  def handle_call({:start_game, player_id}, _from, state) do
    cond do
      state.host_id != player_id ->
        {:reply, {:error, :not_host}, state}

      true ->
        case validate_start(state.game) do
          :ok ->
            new_game = Game.start_game(state.game)
            started_at = DateTime.utc_now()
            new_state = %{state | game: new_game, updated_at: started_at, started_at: started_at}

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
  end

  @impl true
  def handle_call({:play_cards, player_id, cards}, _from, state) do
    player = Enum.find(state.game.players, &(&1.id == player_id))

    if player do
      # Convert cards to indices for Game.play_card
      card_indices =
        cards
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

            # Check if game just finished and record stats
            if state.game.status != :finished and new_game.status == :finished do
              record_game_stats(new_state)
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

        # Check if game just finished and record stats
        if state.game.status != :finished and new_game.status == :finished do
          record_game_stats(new_state)
        end

        # Schedule AI turn if next player is AI
        schedule_ai_turn_if_needed(new_state)

        {:reply, {:ok, new_state.game}, new_state}

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
        schedule_ai_turn_if_needed(new_state)

        {:reply, {:ok, new_state.game}, new_state}

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

    if current_player && current_player.id == player_id && state.game.status == :playing do
      # Give them 5 seconds to reconnect
      Process.send_after(self(), :ai_turn, 5000)
    end

    {:noreply, new_state}
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

        if current_player && current_player.id == player_id && state.game.status == :playing do
          # 10 second grace period
          Process.send_after(self(), {:check_disconnected_player, player_id}, 10000)
        end

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:check_disconnected_player, player_id}, state) do
    # Check if player is still disconnected after grace period
    if Map.get(state.connected_players, player_id) == false && state.game.status == :playing do
      # Convert to AI
      new_players =
        Enum.map(state.game.players, fn player ->
          if player.id == player_id do
            %{player | is_ai: true}
          else
            player
          end
        end)

      new_game = %{state.game | players: new_players}
      new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}

      broadcast_game_update(new_state)

      # If it's their turn, trigger AI move
      current_player = Enum.at(new_game.players, new_game.current_player_index)

      if current_player && current_player.id == player_id do
        Process.send_after(self(), :ai_turn, 1000)
      end

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:ai_turn, state) do
    current_player = Enum.at(state.game.players, state.game.current_player_index)

    if current_player && current_player.is_ai && state.game.status == :playing do
      # Get AI decision
      action = Rachel.Games.AIPlayer.make_move(state.game, current_player.id)

      # Execute AI action
      new_state =
        case action do
          {:play, card_index} ->
            case Game.play_card(state.game, current_player.id, [card_index]) do
              {:ok, new_game} ->
                new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
                played_card = Enum.at(current_player.hand, card_index)
                broadcast_cards_played(new_state, current_player.id, [played_card])

                # Check if game finished
                if state.game.status != :finished and new_game.status == :finished do
                  record_game_stats(new_state)
                end

                # Schedule next AI turn if needed
                schedule_ai_turn_if_needed(new_state)
                new_state

              {:error, _} ->
                # AI made invalid play, force draw
                Process.send_after(self(), :ai_turn, 100)
                state
            end

          {:draw, _} ->
            case Game.draw_card(state.game, current_player.id) do
              {:ok, new_game} ->
                new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
                broadcast_card_drawn(new_state, current_player.id)

                # Check if game finished
                if state.game.status != :finished and new_game.status == :finished do
                  record_game_stats(new_state)
                end

                # Schedule next AI turn if needed
                schedule_ai_turn_if_needed(new_state)
                new_state

              {:error, _} ->
                state
            end

          {:nominate, suit} ->
            case Game.nominate_suit(state.game, current_player.id, suit) do
              {:ok, new_game} ->
                new_state = %{state | game: new_game, updated_at: DateTime.utc_now()}
                broadcast_suit_nominated(new_state, current_player.id, suit)

                # Schedule next AI turn if needed
                schedule_ai_turn_if_needed(new_state)
                new_state

              {:error, _} ->
                state
            end
        end

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:ai_timeout, state) do
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

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
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
    current_player = Enum.at(state.game.players, state.game.current_player_index)

    if current_player && current_player.is_ai do
      Process.send_after(self(), :ai_turn, 1500)
    end
  end

  # Stats recording

  defp record_game_stats(state) do
    if state.started_at do
      ended_at = DateTime.utc_now()
      game_id = state.game.id

      # Record stats asynchronously to avoid blocking the game
      Task.start(fn ->
        try do
          AccountsStats.record_game(state.game, game_id, state.started_at, ended_at)
        rescue
          error ->
            # Log error but don't crash the game server
            require Logger
            Logger.error("Failed to record game stats for game #{game_id}: #{inspect(error)}")
        end
      end)
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
end
