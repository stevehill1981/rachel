defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Phoenix.LiveView.Socket
  alias Phoenix.PubSub
  alias Rachel.Games.{GameManager, GameServer}

  alias RachelWeb.GameLive.{
    Actions,
    AIManager,
    EventHandlers,
    PracticeGame,
    PubSubHandlers,
    SessionManager,
    StateManager
  }

  alias RachelWeb.Validation

  @type socket_update ::
          {:assign, atom(), any()}
          | {:schedule_ai_move, map()}
          | {:send_after_self, atom(), non_neg_integer()}

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(%{"game_id" => game_id}, _session, socket) do
    # Handle direct game join via URL
    player_id = socket.assigns.player_id
    player_name = socket.assigns.player_name || generate_random_name()

    case SessionManager.handle_game_join(game_id, player_id, player_name) do
      {:ok, game} ->
        # Subscribe to game updates
        PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")

        # Notify GameServer that we're connected
        try do
          GameServer.player_connected(game_id, player_id, self())
        catch
          :exit, _ -> :ok
        end

        socket =
          socket
          |> assign(:game, StateManager.normalize_game_data(game))
          |> assign(:game_id, game_id)
          |> assign(:player_id, player_id)
          |> assign(:player_name, player_name)
          |> assign(:selected_cards, [])
          |> assign(:show_winner_banner, false)
          |> assign(:winner_acknowledged, false)
          |> assign(:celebration_shown, false)

        {:ok, socket}

      {:error, _reason} ->
        {:ok, push_navigate(socket, to: "/")}
    end
  end

  # Fallback for single-player mode or creating new multiplayer game
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _session, socket) do
    # Check if we're creating a new game
    case socket.assigns.live_action do
      :create_multiplayer ->
        # Redirect to home page - multiplayer creation happens there now
        {:ok, push_navigate(socket, to: "/")}

      :create_with_ai ->
        # Create AI game instantly with generated name
        player_name =
          if socket.assigns.player_name && String.trim(socket.assigns.player_name) != "" do
            socket.assigns.player_name
          else
            generate_random_name()
          end

        case create_ai_game(socket.assigns.player_id, player_name) do
          {:ok, game_id} ->
            {:ok, push_navigate(socket, to: "/game/#{game_id}")}

          {:error, _reason} ->
            {:ok, push_navigate(socket, to: "/")}
        end

      _ ->
        # Single-player practice mode
        player_name = socket.assigns.player_name
        game = PracticeGame.create_test_game(player_name)

        socket =
          socket
          |> assign(:game, StateManager.normalize_game_data(game))
          |> assign(:game_id, nil)
          # player_id and player_name are already set by the hook
          |> assign(:selected_cards, [])
          |> assign(:show_winner_banner, false)
          |> assign(:winner_acknowledged, false)
          |> assign(:celebration_shown, false)

        # Check if AI should start
        AIManager.schedule_ai_move(game)

        # Check if player needs to auto-draw
        auto_draw_updates = StateManager.check_auto_draw_updates(game, socket.assigns.player_id)
        socket = apply_socket_updates(socket, auto_draw_updates)

        {:ok, socket}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("select_card", %{"index" => index_str}, socket) do
    with {:ok, _} <- Validation.validate_rate_limit(socket.assigns.player_id, :select_card),
         {index, ""} <- Integer.parse(index_str),
         {:ok, _} <-
           Validation.validate_card_indices([index], length(get_current_player_hand(socket))) do
      case StateManager.validate_player_turn(socket) do
        {:ok, current_player} ->
          case EventHandlers.handle_card_selection(
                 socket.assigns.selected_cards,
                 current_player,
                 index
               ) do
            {:ok, update} ->
              updated_socket = apply_socket_update(socket, update)

              # Always require explicit play button click
              {:noreply, updated_socket}

            {:error, _reason} ->
              {:noreply, socket}
          end

        :not_player_turn ->
          {:noreply, socket}
      end
    else
      {:error, _reason} ->
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("play_cards", _, socket) do
    case Validation.validate_rate_limit(socket.assigns.player_id, :play_card) do
      {:ok, _} ->
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

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("draw_card", _, socket) do
    case Validation.validate_rate_limit(socket.assigns.player_id, :draw_card) do
      {:ok, _} ->
        case StateManager.validate_player_turn(socket) do
          {:ok, _current_player} ->
            case EventHandlers.handle_draw_card(socket) do
              {:ok, updates} ->
                {:noreply, apply_socket_updates(socket, updates)}

              {:error, _reason} ->
                {:noreply, socket}
            end

          :not_player_turn ->
            {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("nominate_suit", %{"suit" => suit}, socket) do
    with {:ok, _} <- Validation.validate_rate_limit(socket.assigns.player_id, :nominate_suit),
         {:ok, suit_atom} <- Validation.validate_suit(suit) do
      case StateManager.validate_player_turn(socket) do
        {:ok, _current_player} ->
          case EventHandlers.handle_nominate_suit(socket, suit_atom, suit) do
            {:ok, updates} ->
              {:noreply, apply_socket_updates(socket, updates)}

            {:error, _reason} ->
              {:noreply, socket}
          end

        :not_player_turn ->
          {:noreply, socket}
      end
    else
      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("acknowledge_win", _, socket) do
    {:noreply, assign(socket, :show_winner_banner, false)}
  end

  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("start_game", _, socket) do
    if socket.assigns.game_id && socket.assigns.player_id do
      case GameServer.start_game(socket.assigns.game_id, socket.assigns.player_id) do
        {:ok, _game} ->
          {:noreply, socket}

        {:error, :not_host} ->
          {:noreply, socket}

        {:error, :not_enough_players} ->
          {:noreply, socket}

        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("return_to_lobby", _, socket) do
    require Logger
    Logger.info("return_to_lobby event received, navigating to home")
    {:noreply, push_navigate(socket, to: "/")}
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    # Use the same window event approach as the root layout
    {:noreply, push_event(socket, "phx:set-theme", %{theme: theme})}
  end

  @impl true
  @spec handle_info(any(), Socket.t()) :: {:noreply, Socket.t()}
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

  @spec handle_info(atom(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_info(:auto_hide_winner_banner, socket) do
    updates = PubSubHandlers.handle_auto_hide_winner_banner()
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info(atom(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_info(:auto_draw_pending_cards, socket) do
    case PubSubHandlers.handle_auto_draw_pending_cards(
           socket.assigns.game,
           socket.assigns.player_id
         ) do
      {:draw_card_with_message, _message} ->
        case Actions.draw_card_action(socket) do
          {:ok, new_game} ->
            socket =
              socket
              |> assign(:game, StateManager.normalize_game_data(new_game))
              |> assign(:selected_cards, [])

            {:noreply, socket}

          {:error, _} ->
            {:noreply, socket}
        end

      :noreply ->
        {:noreply, socket}
    end
  end

  # PubSub event handlers for multiplayer games
  @spec handle_info({atom(), any()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:game_updated, game}, socket) do
    updates = PubSubHandlers.handle_game_updated(game, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), map()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:cards_played, msg}, socket) do
    updates = PubSubHandlers.handle_cards_played(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), map()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:card_drawn, msg}, socket) do
    updates = PubSubHandlers.handle_card_drawn(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), map()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:suit_nominated, msg}, socket) do
    updates = PubSubHandlers.handle_suit_nominated(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), map()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:player_won, msg}, socket) do
    updates = PubSubHandlers.handle_player_won(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), any()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:game_started, game}, socket) do
    updates = PubSubHandlers.handle_game_started(game)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), map()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:player_reconnected, msg}, socket) do
    updates = PubSubHandlers.handle_player_reconnected(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  @spec handle_info({atom(), map()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:player_disconnected, msg}, socket) do
    updates = PubSubHandlers.handle_player_disconnected(msg, socket.assigns.player_id)
    {:noreply, apply_socket_updates(socket, updates)}
  end

  # Catch-all for unexpected messages
  @spec handle_info(any(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="game-board min-h-screen">
      <!-- Theme Management -->
      <div phx-hook="ThemeBridge" id="theme-bridge"></div>
      
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
              is_spectator={Map.get(assigns, :is_spectator, false)}
              commentary_feed={Map.get(assigns, :commentary_feed, [])}
              spectator_show_cards={Map.get(assigns, :spectator_show_cards, false)}
              spectator_show_stats={Map.get(assigns, :spectator_show_stats, false)}
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

  @spec execute_play_cards_action(Socket.t(), [map()]) :: {:noreply, Socket.t()}
  defp execute_play_cards_action(socket, selected_cards) do
    case Actions.play_cards_action(socket, selected_cards) do
      {:ok, new_game} ->
        winner_updates =
          StateManager.check_and_show_winner_banner_updates(
            new_game,
            socket.assigns.player_id,
            socket.assigns.celebration_shown
          )

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

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @spec apply_socket_updates(Socket.t(), [socket_update()]) :: Socket.t()
  defp apply_socket_updates(socket, updates) do
    Enum.reduce(updates, socket, &apply_socket_update(&2, &1))
  end

  @spec apply_socket_update(Socket.t(), socket_update()) :: Socket.t()
  defp apply_socket_update(socket, {:assign, key, value}) do
    assign(socket, key, value)
  end

  @spec apply_socket_update(Socket.t(), socket_update()) :: Socket.t()
  defp apply_socket_update(socket, {:schedule_ai_move, game}) do
    AIManager.schedule_ai_move(game)
    socket
  end

  @spec apply_socket_update(Socket.t(), socket_update()) :: Socket.t()
  defp apply_socket_update(socket, {:send_after_self, message, delay}) do
    Process.send_after(self(), message, delay)
    socket
  end

  # Catch-all clause for unexpected update types
  @spec apply_socket_update(Socket.t(), any()) :: Socket.t()
  defp apply_socket_update(socket, _unknown_update) do
    # Log the unknown update for debugging if needed
    # require Logger
    # Logger.warning("Unknown socket update: #{inspect(unknown_update)}")
    socket
  end

  defp get_current_player_hand(socket) do
    case get_current_player(socket) do
      nil -> []
      player -> player.hand
    end
  end

  defp get_current_player(socket) do
    game = socket.assigns.game
    current_player_id = socket.assigns.player_id
    Enum.find(game.players, &(&1.id == current_player_id))
  end

  # Create a game with AI opponents (3 AI + 1 human = 4 players total)
  defp create_ai_game(player_id, player_name) do
    case GameManager.create_and_join_game(player_id, player_name) do
      {:ok, game_id} ->
        # Add 3 AI players for a 4-player game
        GameServer.add_ai_player(game_id, "AI Charlie")
        GameServer.add_ai_player(game_id, "AI Sam")
        GameServer.add_ai_player(game_id, "AI Alex")

        # Start the game immediately
        case GameServer.start_game(game_id, player_id) do
          {:ok, _game} ->
            {:ok, game_id}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_random_name do
    adjectives = ["Quick", "Clever", "Lucky", "Swift", "Bold", "Bright", "Sharp", "Wise"]
    nouns = ["Player", "Gamer", "Card", "Star", "Hero", "Ace", "King", "Queen"]

    "#{Enum.random(adjectives)} #{Enum.random(nouns)}"
  end
end
