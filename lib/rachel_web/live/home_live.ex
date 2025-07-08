defmodule RachelWeb.HomeLive do
  use RachelWeb, :live_view
  alias Rachel.Games.GameManager
  alias RachelWeb.GameLive.SessionManager

  @impl true
  def mount(_params, _session, socket) do
    # We'll load the player name from localStorage on the client side
    socket =
      socket
      |> assign(:player_name, "")
      |> assign(:game_code, "")
      |> assign(:creating_game, false)
      |> assign(:joining_game, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100" phx-hook="PlayerName" id="home-page">
      <div class="max-w-4xl mx-auto px-4 py-16 sm:px-6 lg:px-8">
        <!-- Hero Section -->
        <div class="text-center mb-12">
          <h1 class="text-5xl font-bold text-gray-900 mb-4">
            🃏 Rachel
          </h1>
          <p class="text-xl text-gray-600 max-w-2xl mx-auto">
            The strategic card game that's been bringing friends and families together for over 30 years
          </p>
        </div>

        <!-- Game Options -->
        <div class="space-y-8">
          <!-- Instant AI Play -->
          <div class="bg-white rounded-2xl shadow-lg p-8 text-center">
            <h2 class="text-2xl font-bold text-gray-900 mb-4">Quick Play</h2>
            <a
              href="/play"
              class="inline-flex items-center px-8 py-4 text-lg font-bold text-white bg-gradient-to-r from-green-500 to-blue-500 rounded-xl hover:from-green-600 hover:to-blue-600 focus:outline-none focus:ring-4 focus:ring-green-300 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-1"
            >
              <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              Play vs AI
            </a>
            <p class="text-sm text-gray-500 mt-3">Start instantly with a randomly generated name</p>
          </div>

          <!-- Multiplayer Options -->
          <div class="bg-white rounded-2xl shadow-lg p-8">
            <h2 class="text-2xl font-bold text-gray-900 mb-6 text-center">Multiplayer</h2>
            
            <div class="grid md:grid-cols-2 gap-8">
              <!-- Create Game -->
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-gray-900">Create Game</h3>
                <form phx-submit="create_game" class="space-y-3">
                  <input
                    type="text"
                    name="player_name"
                    value={@player_name}
                    phx-change="update_player_name"
                    placeholder={if @player_name == "", do: "Your name", else: ""}
                    maxlength="20"
                    required
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                  <button
                    type="submit"
                    disabled={@creating_game || String.trim(@player_name) == ""}
                    class={[
                      "w-full py-3 px-4 rounded-lg font-medium transition-colors",
                      if(@creating_game || String.trim(@player_name) == "",
                        do: "bg-gray-300 cursor-not-allowed text-gray-500",
                        else: "bg-blue-500 hover:bg-blue-600 text-white"
                      )
                    ]}
                  >
                    <%= if @creating_game, do: "Creating...", else: "Create Game" %>
                  </button>
                </form>
              </div>

              <!-- Join Game -->
              <div class="space-y-4">
                <h3 class="text-lg font-semibold text-gray-900">Join Game</h3>
                <form phx-submit="join_game" class="space-y-3">
                  <input
                    type="text"
                    name="game_code"
                    value={@game_code}
                    phx-change="update_game_code"
                    placeholder="Game code"
                    maxlength="10"
                    required
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 uppercase"
                  />
                  <input
                    type="text"
                    name="player_name"
                    value={@player_name}
                    phx-change="update_player_name"
                    placeholder={if @player_name == "", do: "Your name", else: ""}
                    maxlength="20"
                    required
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                  <button
                    type="submit"
                    disabled={@joining_game || String.trim(@player_name) == "" || String.trim(@game_code) == ""}
                    class={[
                      "w-full py-3 px-4 rounded-lg font-medium transition-colors",
                      if(@joining_game || String.trim(@player_name) == "" || String.trim(@game_code) == "",
                        do: "bg-gray-300 cursor-not-allowed text-gray-500",
                        else: "bg-green-500 hover:bg-green-600 text-white"
                      )
                    ]}
                  >
                    <%= if @joining_game, do: "Joining...", else: "Join Game" %>
                  </button>
                </form>
              </div>
            </div>
          </div>

          <!-- How to Play Summary -->
          <div class="bg-gradient-to-r from-indigo-600 to-blue-600 rounded-2xl shadow-lg p-8 text-white">
            <h3 class="text-xl font-bold mb-4">Quick Rules</h3>
            <div class="grid md:grid-cols-2 gap-6 text-sm">
              <div>
                <p class="font-semibold mb-2">Basic Play:</p>
                <ul class="space-y-1 text-white/90">
                  <li>• Match suit or rank</li>
                  <li>• Draw if you can't play</li>
                  <li>• First to empty hand wins</li>
                </ul>
              </div>
              <div>
                <p class="font-semibold mb-2">Special Cards:</p>
                <ul class="space-y-1 text-white/90">
                  <li>• 2s = Pick up 2</li>
                  <li>• 7s = Skip turn</li>
                  <li>• Queens = Reverse</li>
                  <li>• Aces = Wild card</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_player_name", %{"player_name" => name}, socket) do
    # Save to localStorage via client-side hook
    socket = 
      if String.trim(name) != "" do
        push_event(socket, "save_player_name", %{name: String.trim(name)})
      else
        socket
      end
    
    {:noreply, assign(socket, :player_name, name)}
  end

  def handle_event("load_saved_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :player_name, name)}
  end

  def handle_event("update_game_code", %{"game_code" => code}, socket) do
    {:noreply, assign(socket, :game_code, String.upcase(code))}
  end

  def handle_event("create_game", %{"player_name" => name}, socket) do
    socket = assign(socket, :creating_game, true)
    player_id = socket.assigns.player_id
    
    case GameManager.create_and_join_game(player_id, String.trim(name)) do
      {:ok, game_id} ->
        {:noreply, push_navigate(socket, to: "/game/#{game_id}/lobby")}
      
      {:error, _reason} ->
        socket =
          socket
          |> assign(:creating_game, false)
          |> put_flash(:error, "Failed to create game. Please try again.")
        
        {:noreply, socket}
    end
  end

  def handle_event("join_game", %{"game_code" => code, "player_name" => name}, socket) do
    socket = assign(socket, :joining_game, true)
    player_id = socket.assigns.player_id
    game_id = String.trim(String.upcase(code))
    
    case SessionManager.handle_game_join(game_id, player_id, String.trim(name)) do
      {:ok, _game} ->
        {:noreply, push_navigate(socket, to: "/game/#{game_id}")}
      
      {:error, :game_not_found} ->
        socket =
          socket
          |> assign(:joining_game, false)
          |> put_flash(:error, "Game not found. Please check the code.")
        
        {:noreply, socket}
      
      {:error, :game_full} ->
        socket =
          socket
          |> assign(:joining_game, false)
          |> put_flash(:error, "Game is full (8 players max).")
        
        {:noreply, socket}
      
      {:error, _reason} ->
        socket =
          socket
          |> assign(:joining_game, false)
          |> put_flash(:error, "Failed to join game. Please try again.")
        
        {:noreply, socket}
    end
  end
end