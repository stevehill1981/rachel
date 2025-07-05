defmodule RachelWeb.LobbyLive do
  @moduledoc """
  LiveView for the game lobby where players can create and join games.
  """
  use RachelWeb, :live_view

  alias Phoenix.LiveView.Socket
  alias Phoenix.PubSub
  alias Rachel.Games.GameManager
  alias RachelWeb.Validation

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, session, socket) do
    # Subscribe to lobby updates
    PubSub.subscribe(Rachel.PubSub, "lobby")

    # Get player info from session (set by PlayerSession plug)
    player_id = Map.get(session, "player_id", generate_player_id())
    player_name = Map.get(session, "player_name", generate_default_name())

    socket =
      socket
      |> assign(:player_id, player_id)
      |> assign(:player_name, player_name)
      |> assign(:games, GameManager.list_active_games())
      |> assign(:creating_game, false)
      |> assign(:joining_game, nil)
      |> assign(:join_code, "")
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("create_game", _params, socket) do
    with {:ok, _} <- Validation.validate_rate_limit(socket.assigns.player_id, :create_game),
         {:ok, _} <- Validation.validate_player_name(socket.assigns.player_name) do
      case GameManager.create_and_join_game(socket.assigns.player_id, socket.assigns.player_name) do
        {:ok, game_id} ->
          # Broadcast lobby update
          broadcast_lobby_update()

          # Redirect to the game
          {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}

        {:error, reason} ->
          {:noreply, assign(socket, :error_message, "Failed to create game: #{reason}")}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, :error_message, reason)}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("join_game", %{"game_id" => game_id}, socket) do
    with {:ok, _} <- Validation.validate_rate_limit(socket.assigns.player_id, :join_game),
         {:ok, validated_game_id} <- Validation.validate_game_id(game_id),
         {:ok, _} <- Validation.validate_player_name(socket.assigns.player_name) do
      case GameManager.join_game(
             validated_game_id,
             socket.assigns.player_id,
             socket.assigns.player_name
           ) do
        {:ok, _game} ->
          # Broadcast lobby update
          broadcast_lobby_update()

          # Redirect to the game
          {:noreply, push_navigate(socket, to: ~p"/game/#{validated_game_id}")}

        {:error, reason} ->
          error_msg =
            case reason do
              :game_not_found -> "Game not found"
              :game_full -> "Game is full"
              :already_joined -> "You're already in this game"
              :game_started -> "Game has already started"
              _ -> "Failed to join game: #{reason}"
            end

          {:noreply, assign(socket, :error_message, error_msg)}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, :error_message, reason)}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("join_by_code", %{"join_code" => code}, socket) do
    # For now, treat the code as a game ID
    # Later we can implement proper game codes
    case GameManager.join_game(code, socket.assigns.player_id, socket.assigns.player_name) do
      {:ok, _game} ->
        broadcast_lobby_update()
        {:noreply, push_navigate(socket, to: ~p"/game/#{code}")}

      {:error, reason} ->
        error_msg =
          case reason do
            :game_not_found -> "Invalid game code"
            :game_full -> "Game is full"
            :already_joined -> "You're already in this game"
            :game_started -> "Game has already started"
            _ -> "Failed to join game: #{reason}"
          end

        {:noreply, assign(socket, :error_message, error_msg)}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("update_player_name", %{"player_name" => name}, socket) do
    {:noreply, assign(socket, :player_name, String.trim(name))}
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("clear_error", _params, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("refresh_games", _params, socket) do
    {:noreply, assign(socket, :games, GameManager.list_active_games())}
  end

  @impl true
  @spec handle_info({atom(), any()}, Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:lobby_updated, _}, socket) do
    # Refresh the game list when lobby is updated
    {:noreply, assign(socket, :games, GameManager.list_active_games())}
  end

  # Helper functions

  @spec generate_player_id() :: String.t()
  defp generate_player_id do
    "player-#{System.unique_integer([:positive])}"
  end

  @spec generate_default_name() :: String.t()
  defp generate_default_name do
    adjectives = ["Swift", "Clever", "Bold", "Lucky", "Wise", "Brave", "Quick", "Sharp"]
    nouns = ["Fox", "Eagle", "Wolf", "Bear", "Lion", "Tiger", "Hawk", "Owl"]

    adjective = Enum.random(adjectives)
    noun = Enum.random(nouns)

    "#{adjective}#{noun}"
  end

  @spec broadcast_lobby_update() :: :ok | {:error, any()}
  defp broadcast_lobby_update do
    PubSub.broadcast(Rachel.PubSub, "lobby", {:lobby_updated, :games_changed})
  end

  @spec format_player_list([map()]) :: String.t()
  defp format_player_list(players) do
    Enum.map_join(players, ", ", & &1.name)
  end

  @spec game_status_badge(atom()) :: String.t()
  defp game_status_badge(status) do
    case status do
      :waiting -> "bg-yellow-100 text-yellow-800"
      :playing -> "bg-green-100 text-green-800"
      :finished -> "bg-gray-100 text-gray-800"
    end
  end

  @spec can_join_game?(map()) :: boolean()
  defp can_join_game?(game) do
    game.status == :waiting and length(game.players) < 8
  end
end
