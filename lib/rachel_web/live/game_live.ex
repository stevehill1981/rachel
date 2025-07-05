defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Phoenix.PubSub
  alias Rachel.Games.GameServer

  alias RachelWeb.GameLive.{
    Actions,
    AIManager,
    EventHandlers,
    PracticeGame,
    PubSubHandlers,
    SessionManager,
    StateManager
  }

  import RachelWeb.CoreComponents

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    # Generate or get player identity
    player_id = SessionManager.get_player_id(session)
    player_name = SessionManager.get_player_name(session)

    case SessionManager.handle_game_join(game_id, player_id, player_name) do
      {:ok, game} ->
        # Subscribe to game updates
        PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

        # Notify GameServer that we're connected
        try do
          GameServer.player_connected(game_id, player_id, self())
        catch
          # Continue even if GameServer notification fails
          :exit, _ -> :ok
        end

        socket =
          socket
          |> assign(:game, StateManager.normalize_game_data(game))
          |> assign(:game_id, game_id)
          |> assign(:player_id, player_id)
          |> assign(:player_name, player_name)
          |> assign(:selected_cards, [])
          |> assign(:show_ai_thinking, false)
          |> assign(:show_winner_banner, false)
          |> assign(:winner_acknowledged, false)
          |> assign(:connection_status, :connected)
          |> assign(:is_spectator, false)

        {:ok, socket}

      {:ok, game, :spectator} ->
        # Subscribe to game updates as spectator
        PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

        socket =
          socket
          |> assign(:game, StateManager.normalize_game_data(game))
          |> assign(:game_id, game_id)
          |> assign(:player_id, player_id)
          |> assign(:player_name, player_name)
          |> assign(:selected_cards, [])
          |> assign(:show_ai_thinking, false)
          |> assign(:show_winner_banner, false)
          |> assign(:winner_acknowledged, false)
          |> assign(:connection_status, :connected)
          |> assign(:is_spectator, true)
          |> put_flash(:info, "Joined as spectator - watching the game!")

        {:ok, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, SessionManager.format_join_error(reason))
          |> push_navigate(to: "/lobby")

        {:ok, socket}
    end
  end

  # Fallback for single-player mode (no game_id)
  def mount(_params, _session, socket) do
    # For single-player practice games, always use "You" for better UX
    player_name = "You"
    game = PracticeGame.create_test_game(player_name)

    socket =
      socket
      |> assign(:game, StateManager.normalize_game_data(game))
      |> assign(:game_id, nil)
      |> assign(:player_id, "human")
      |> assign(:player_name, player_name)
      |> assign(:selected_cards, [])
      |> assign(:show_ai_thinking, false)
      |> assign(:show_winner_banner, false)
      |> assign(:winner_acknowledged, false)
      |> assign(:connection_status, :offline)

    # Check if AI should start
    AIManager.schedule_ai_move(game)

    # Check if player needs to auto-draw
    auto_draw_updates = StateManager.check_auto_draw_updates(game, "human")
    socket = apply_socket_updates(socket, auto_draw_updates)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_card", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    case StateManager.validate_player_turn(socket) do
      {:ok, current_player} ->
        case EventHandlers.handle_card_selection(
               socket.assigns.selected_cards,
               current_player,
               index
             ) do
          {:ok, update} ->
            {:noreply, apply_socket_update(socket, update)}

          {:error, _reason} ->
            {:noreply, socket}
        end

      :not_player_turn ->
        {:noreply, socket}
    end
  end

  def handle_event("play_cards", _, socket) do
    case EventHandlers.handle_play_cards(
           socket.assigns.game,
           socket.assigns.player_id,
           socket.assigns.selected_cards
         ) do
      {:ok, {:play_cards_action, selected_cards}} ->
        execute_play_cards_action(socket, selected_cards)

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("draw_card", _, socket) do
    case StateManager.validate_player_turn(socket) do
      {:ok, _current_player} ->
        case EventHandlers.handle_draw_card(socket) do
          {:ok, updates} ->
            {:noreply, apply_socket_updates(socket, updates)}

          {:error, reason} ->
            {:noreply, socket |> clear_flash() |> put_flash(:error, reason)}
        end

      :not_player_turn ->
        {:noreply, socket}
    end
  end

  def handle_event("nominate_suit", %{"suit" => suit}, socket) do
    case StateManager.validate_player_turn(socket) do
      {:ok, _current_player} ->
        suit_atom = String.to_existing_atom(suit)

        case EventHandlers.handle_nominate_suit(socket, suit_atom, suit) do
          {:ok, updates} ->
            {:noreply, apply_socket_updates(socket, updates)}

          {:error, reason} ->
            {:noreply, socket |> clear_flash() |> put_flash(:error, reason)}
        end

      :not_player_turn ->
        {:noreply, socket}
    end
  end

  def handle_event("acknowledge_win", _, socket) do
    {:noreply, assign(socket, :show_winner_banner, false)}
  end

  def handle_event("copy_game_code", _, socket) do
    if socket.assigns.game_id do
      game_code = String.slice(socket.assigns.game_id, -6..-1)
      {:noreply, put_flash(socket, :info, "Game code #{game_code} copied!")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("start_game", _, socket) do
    if socket.assigns.game_id && socket.assigns.player_id do
      case GameServer.start_game(socket.assigns.game_id, socket.assigns.player_id) do
        {:ok, _game} ->
          {:noreply, put_flash(socket, :info, "Game started!")}

        {:error, :not_host} ->
          {:noreply, put_flash(socket, :error, "Only the host can start the game")}

        {:error, :not_enough_players} ->
          {:noreply, put_flash(socket, :error, "Need at least 2 players to start")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to start game: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:ai_move, socket) do
    # Only handle AI moves for single-player games
    if socket.assigns.game_id do
      {:noreply, socket}
    else
      case AIManager.handle_single_player_ai_move(socket.assigns.game) do
        {:ok, updates} ->
          {:noreply, apply_socket_updates(socket, updates)}

        {:noreply} ->
          {:noreply, socket}
      end
    end
  end

  def handle_info(:auto_hide_winner_banner, socket) do
    updates = PubSubHandlers.handle_auto_hide_winner_banner()
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info(:auto_draw_pending_cards, socket) do
    case PubSubHandlers.handle_auto_draw_pending_cards(
           socket.assigns.game,
           socket.assigns.player_id
         ) do
      {:draw_card_with_message, message} ->
        case Actions.draw_card_action(socket) do
          {:ok, new_game} ->
            socket =
              socket
              |> assign(:game, StateManager.normalize_game_data(new_game))
              |> assign(:selected_cards, [])
              |> clear_flash()
              |> put_flash(:info, message)

            {:noreply, socket}

          {:error, _} ->
            {:noreply, socket}
        end

      :noreply ->
        {:noreply, socket}
    end
  end

  # PubSub event handlers for multiplayer games
  def handle_info({:game_updated, game}, socket) do
    updates = PubSubHandlers.handle_game_updated(game, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:cards_played, msg}, socket) do
    updates = PubSubHandlers.handle_cards_played(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:card_drawn, msg}, socket) do
    updates = PubSubHandlers.handle_card_drawn(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:suit_nominated, msg}, socket) do
    updates = PubSubHandlers.handle_suit_nominated(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:player_won, msg}, socket) do
    updates = PubSubHandlers.handle_player_won(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:game_started, game}, socket) do
    updates = PubSubHandlers.handle_game_started(game)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:player_reconnected, msg}, socket) do
    updates = PubSubHandlers.handle_player_reconnected(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  def handle_info({:player_disconnected, msg}, socket) do
    updates = PubSubHandlers.handle_player_disconnected(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  # Catch-all for unexpected messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game-board min-h-screen">
      <RachelWeb.Components.Game.GameHeader.game_header game_id={@game_id} />
      
    <!-- Flash Messages -->
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      
    <!-- Main Game Area -->
      <main class="relative z-10 p-4 max-w-7xl mx-auto">
        <%= cond do %>
          <% !@game -> %>
            <div class="text-center text-white">
              <h1 class="text-4xl font-bold mb-4">Rachel</h1>
              <p>Loading game...</p>
            </div>
          <% @game.status == :waiting -> %>
            <RachelWeb.Components.Game.WaitingRoom.waiting_room
              game={@game}
              game_id={@game_id}
              player_id={@player_id}
            />
          <% true -> %>
            <RachelWeb.Components.Game.GameInProgress.game_in_progress
              game={@game}
              player_id={@player_id}
              selected_cards={@selected_cards}
              show_ai_thinking={@show_ai_thinking}
              is_spectator={Map.get(assigns, :is_spectator, false)}
            />
        <% end %>
      </main>
      
    <!-- Winner celebration -->
      <%= if @show_winner_banner do %>
        <div id="confetti-container" class="winner-celebration" phx-hook="WinnerCelebration"></div>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp execute_play_cards_action(socket, selected_cards) do
    case Actions.play_cards_action(socket, selected_cards) do
      {:ok, new_game} ->
        winner_updates =
          StateManager.check_and_show_winner_banner_updates(new_game, socket.assigns.player_id)

        auto_draw_updates =
          StateManager.check_auto_draw_updates(new_game, socket.assigns.player_id)

        updates =
          [
            {:assign, :game, StateManager.normalize_game_data(new_game)},
            {:assign, :selected_cards, []}
          ] ++ winner_updates ++ auto_draw_updates

        # Schedule AI move for single-player games
        if socket.assigns.game_id == nil do
          AIManager.schedule_ai_move(new_game)
        end

        {:noreply, apply_socket_updates(socket, updates)}

      {:error, reason} ->
        {:noreply, socket |> clear_flash() |> put_flash(:error, Actions.format_error(reason))}
    end
  end

  defp apply_socket_updates(socket, updates) do
    Enum.reduce(updates, socket, &apply_socket_update(&2, &1))
  end

  defp apply_socket_update(socket, {:assign, key, value}) do
    assign(socket, key, value)
  end

  defp apply_socket_update(socket, {:put_flash, type, message}) do
    put_flash(socket, type, message)
  end

  defp apply_socket_update(socket, {:clear_flash}) do
    clear_flash(socket)
  end

  defp apply_socket_update(socket, {:schedule_ai_move, game}) do
    AIManager.schedule_ai_move(game)
    socket
  end

  defp apply_socket_update(socket, {:send_after_self, message, delay}) do
    Process.send_after(self(), message, delay)
    socket
  end
end
