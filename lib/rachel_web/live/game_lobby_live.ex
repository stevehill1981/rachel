defmodule RachelWeb.GameLobbyLive do
  use RachelWeb, :live_view
  alias Rachel.Games.GameServer
  alias Phoenix.PubSub

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    player_id = socket.assigns.player_id
    
    # Subscribe to game updates
    PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
    
    # Get current game state
    case GameServer.get_state(game_id) do
      nil ->
        {:ok, push_navigate(socket, to: "/")}
      
      game ->
        # Check if player is the host
        is_host = game.host_id == player_id
        
        # Check if player is in the game
        is_player = Enum.any?(game.players, &(&1.id == player_id))
        
        if is_player do
          socket =
            socket
            |> assign(:game_id, game_id)
            |> assign(:game, game)
            |> assign(:is_host, is_host)
            |> assign(:adding_ai, false)
          
          {:ok, socket}
        else
          # Not in the game, redirect to join
          {:ok, push_navigate(socket, to: "/game/#{game_id}")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div class="max-w-4xl mx-auto px-4 py-16 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">Game Lobby</h1>
          <div class="bg-white rounded-lg shadow-md px-6 py-3 inline-block">
            <p class="text-sm text-gray-600">Game Code</p>
            <p class="text-2xl font-mono font-bold text-indigo-600">{@game_id}</p>
          </div>
        </div>

        <!-- Players List -->
        <div class="bg-white rounded-2xl shadow-lg p-8 mb-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">
            Players ({length(@game.players)}/8)
          </h2>
          
          <div class="space-y-3">
            <%= for player <- @game.players do %>
              <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div class="flex items-center gap-3">
                  <div class={[
                    "w-10 h-10 rounded-full flex items-center justify-center font-bold",
                    if(player.is_ai,
                      do: "bg-purple-100 text-purple-600",
                      else: "bg-blue-100 text-blue-600"
                    )
                  ]}>
                    <%= if player.is_ai do %>
                      🤖
                    <% else %>
                      {String.first(player.name)}
                    <% end %>
                  </div>
                  <div>
                    <p class="font-medium text-gray-900">{player.name}</p>
                    <p class="text-sm text-gray-500">
                      <%= if player.id == @game.host_id do %>
                        Host
                      <% else %>
                        <%= if player.is_ai, do: "AI Player", else: "Player" %>
                      <% end %>
                    </p>
                  </div>
                </div>
                
                <%= if @is_host && player.is_ai do %>
                  <button
                    phx-click="remove_ai"
                    phx-value-player-id={player.id}
                    class="text-red-500 hover:text-red-700 transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                <% end %>
              </div>
            <% end %>
            
            <!-- Empty slots -->
            <%= for _i <- (length(@game.players) + 1)..8 do %>
              <div class="flex items-center p-3 border-2 border-dashed border-gray-300 rounded-lg text-gray-400">
                <div class="w-10 h-10 rounded-full bg-gray-100 mr-3"></div>
                <p>Empty slot</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Host Controls -->
        <%= if @is_host do %>
          <div class="bg-white rounded-2xl shadow-lg p-8 mb-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Host Controls</h3>
            
            <div class="flex flex-wrap gap-3">
              <button
                phx-click="add_ai"
                disabled={@adding_ai || length(@game.players) >= 8}
                class={[
                  "px-4 py-2 rounded-lg font-medium transition-colors",
                  if(@adding_ai || length(@game.players) >= 8,
                    do: "bg-gray-300 cursor-not-allowed text-gray-500",
                    else: "bg-purple-500 hover:bg-purple-600 text-white"
                  )
                ]}
              >
                <span class="flex items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  <%= if @adding_ai, do: "Adding...", else: "Add AI Player" %>
                </span>
              </button>
              
              <button
                phx-click="start_game"
                disabled={length(@game.players) < 2}
                class={[
                  "px-6 py-2 rounded-lg font-medium transition-colors",
                  if(length(@game.players) < 2,
                    do: "bg-gray-300 cursor-not-allowed text-gray-500",
                    else: "bg-green-500 hover:bg-green-600 text-white"
                  )
                ]}
              >
                <span class="flex items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Start Game
                </span>
              </button>
            </div>
            
            <%= if length(@game.players) < 2 do %>
              <p class="text-sm text-gray-500 mt-3">Need at least 2 players to start</p>
            <% end %>
          </div>
        <% else %>
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center">
            <p class="text-yellow-800">Waiting for host to start the game...</p>
          </div>
        <% end %>

        <!-- Share Link -->
        <div id="copy-section" class="bg-white rounded-2xl shadow-lg p-6 text-center" phx-hook="CopyToClipboard">
          <h3 class="text-lg font-semibold text-gray-900 mb-3">Invite Friends</h3>
          <div class="flex items-center gap-3 max-w-md mx-auto">
            <input
              id="game-url-input"
              type="text"
              value={url(~p"/game/#{@game_id}")}
              readonly
              class="flex-1 px-4 py-2 bg-gray-50 border border-gray-300 rounded-lg font-mono text-sm"
            />
            <button
              phx-click="copy_game_url"
              class="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg font-medium transition-colors"
            >
              Copy
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add_ai", _, socket) do
    socket = assign(socket, :adding_ai, true)
    
    case GameServer.add_ai_player(socket.assigns.game_id, generate_ai_name()) do
      {:ok, _game} ->
        socket =
          socket
          |> assign(:adding_ai, false)
          |> put_flash(:info, "AI player added!")
        
        {:noreply, socket}
      
      {:error, :cannot_add_ai} ->
        socket =
          socket
          |> assign(:adding_ai, false)
          |> put_flash(:error, "Cannot add AI player - game is full or already started")
        
        {:noreply, socket}
      
      {:error, reason} ->
        socket =
          socket
          |> assign(:adding_ai, false)
          |> put_flash(:error, "Failed to add AI player: #{reason}")
        
        {:noreply, socket}
    end
  end

  def handle_event("remove_ai", %{"player-id" => player_id}, socket) do
    case GameServer.remove_player(socket.assigns.game_id, player_id) do
      {:ok, _game} ->
        socket = put_flash(socket, :info, "AI player removed")
        {:noreply, socket}
      
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to remove AI player: #{reason}")
        {:noreply, socket}
    end
  end

  def handle_event("start_game", _, socket) do
    case GameServer.start_game(socket.assigns.game_id, socket.assigns.player_id) do
      {:ok, _game} ->
        {:noreply, push_navigate(socket, to: "/game/#{socket.assigns.game_id}")}
      
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to start game: #{reason}")
        {:noreply, socket}
    end
  end

  def handle_event("copy_game_url", _, socket) do
    game_url = url(~p"/game/#{socket.assigns.game_id}")
    
    socket =
      socket
      |> push_event("copy_to_clipboard", %{text: game_url})
      |> put_flash(:info, "Game URL copied to clipboard!")
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    # Game was updated (player joined, left, etc.)
    {:noreply, assign(socket, :game, game)}
  end

  def handle_info({:game_started, _game}, socket) do
    # Game started, redirect to game
    {:noreply, push_navigate(socket, to: "/game/#{socket.assigns.game_id}")}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp generate_ai_name do
    first_names = ["Clever", "Swift", "Wise", "Bold", "Lucky", "Sneaky", "Brave", "Crafty"]
    last_names = ["Clara", "Max", "Sam", "Alex", "Pat", "Casey", "Jordan", "Drew"]
    
    "#{Enum.random(first_names)} #{Enum.random(last_names)}"
  end
end