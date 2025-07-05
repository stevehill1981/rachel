defmodule RachelWeb.InstantPlayLive do
  @moduledoc """
  Instant play LiveView that starts a game immediately with smart defaults.
  Provides the smoothest possible onboarding experience.
  """

  use RachelWeb, :live_view
  alias Rachel.AI.EnhancedAIPlayer
  alias Rachel.Games.GameServer

  @impl true
  def mount(_params, _session, socket) do
    # Player identity is already set by the hook
    # Smart defaults for instant play
    socket =
      socket
      |> assign(:page_title, "Quick Game")
      |> assign(:game_state, :preparing)
      |> assign(:show_tutorial, true)
      |> assign(:tutorial_step, 1)
      |> assign(:game_id, nil)
      |> assign(:creating_game, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Auto-start game creation unless already done
    if socket.assigns.game_state == :preparing and not socket.assigns.creating_game do
      send(self(), :create_instant_game)
      {:noreply, assign(socket, :creating_game, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    send(self(), :create_instant_game)
    {:noreply, assign(socket, :creating_game, true)}
  end

  @impl true
  def handle_event("skip_tutorial", _params, socket) do
    if socket.assigns.game_id do
      {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}")}
    else
      {:noreply, assign(socket, :show_tutorial, false)}
    end
  end

  @impl true
  def handle_event("next_tutorial_step", _params, socket) do
    new_step = socket.assigns.tutorial_step + 1

    if new_step > 4 do
      # Tutorial complete, start the game
      {:noreply, assign(socket, :show_tutorial, false)}
    else
      {:noreply, assign(socket, :tutorial_step, new_step)}
    end
  end

  @impl true
  def handle_event("customize_opponents", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/practice")}
  end

  @impl true
  def handle_event("select_card", _params, socket) do
    # InstantPlayLive is for tutorial/onboarding, not actual gameplay
    # Redirect to actual game if one exists, otherwise ignore
    if socket.assigns.game_id do
      {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("copy_game_code", _params, socket) do
    # InstantPlayLive doesn't handle game codes - redirect to actual game
    if socket.assigns.game_id do
      {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}")}
    else
      {:noreply, socket}
    end
  end

  # Catch-all for other game events that don't belong in InstantPlayLive
  @impl true
  def handle_event(event, _params, socket)
      when event in [
             "play_cards",
             "draw_card",
             "nominate_suit",
             "toggle_cards",
             "toggle_stats"
           ] do
    # These are gameplay events - redirect to actual game
    if socket.assigns.game_id do
      {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.game_id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:create_instant_game, socket) do
    case create_quick_game(socket.assigns.player_id, socket.assigns.player_name) do
      {:ok, game_id} ->
        socket =
          socket
          |> assign(:game_id, game_id)
          |> assign(:game_state, :ready)
          |> assign(:creating_game, false)

        # If tutorial is skipped, go straight to game
        if socket.assigns.show_tutorial do
          {:noreply, socket}
        else
          {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}
        end

      {:error, reason} ->
        socket =
          socket
          |> assign(:game_state, :error)
          |> assign(:creating_game, false)
          |> put_flash(:error, "Failed to create game: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-50 via-blue-50 to-indigo-100">
      <div class="max-w-4xl mx-auto px-4 py-8">
        
    <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">
            🎮 Quick Game Starting...
          </h1>
          <p class="text-lg text-gray-600">
            Getting everything ready for your first game!
          </p>
        </div>
        
    <!-- Game Preparation Status -->
        <div class="bg-white rounded-xl shadow-lg p-8 mb-8">
          <%= cond do %>
            <% @game_state == :preparing -> %>
              <div class="text-center">
                <div class="inline-flex items-center justify-center w-16 h-16 bg-blue-100 rounded-full mb-4">
                  <svg
                    class="w-8 h-8 text-blue-600 animate-spin"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                    />
                  </svg>
                </div>
                <h2 class="text-2xl font-bold text-gray-900 mb-2">Creating Your Game...</h2>
                <p class="text-gray-600 mb-4">Setting up AI opponents and preparing the deck</p>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="bg-blue-600 h-2 rounded-full w-1/3 animate-pulse"></div>
                </div>
              </div>
            <% @game_state == :ready -> %>
              <div class="text-center">
                <div class="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
                  <svg
                    class="w-8 h-8 text-green-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                </div>
                <h2 class="text-2xl font-bold text-gray-900 mb-2">Game Ready!</h2>
                <p class="text-gray-600 mb-6">
                  Playing as <strong>{@player_name}</strong> against intelligent AI opponents
                </p>

                <div class="flex flex-col sm:flex-row gap-4 justify-center">
                  <%= if @show_tutorial do %>
                    <button
                      phx-click="next_tutorial_step"
                      class="px-8 py-3 bg-gradient-to-r from-green-500 to-blue-500 text-white font-semibold rounded-lg hover:from-green-600 hover:to-blue-600 transition-all shadow-lg"
                    >
                      Continue Tutorial
                    </button>
                    <button
                      phx-click="skip_tutorial"
                      class="px-6 py-3 text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Skip & Play Now
                    </button>
                  <% else %>
                    <a
                      href={~p"/game/#{@game_id}"}
                      class="px-8 py-3 bg-gradient-to-r from-green-500 to-blue-500 text-white font-semibold rounded-lg hover:from-green-600 hover:to-blue-600 transition-all shadow-lg"
                    >
                      🎮 Start Playing
                    </a>
                  <% end %>

                  <button
                    phx-click="customize_opponents"
                    class="px-6 py-3 text-indigo-600 border border-indigo-300 rounded-lg hover:bg-indigo-50 transition-colors"
                  >
                    ⚙️ Customize Opponents
                  </button>
                </div>
              </div>
            <% @game_state == :error -> %>
              <div class="text-center">
                <div class="inline-flex items-center justify-center w-16 h-16 bg-red-100 rounded-full mb-4">
                  <svg
                    class="w-8 h-8 text-red-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </div>
                <h2 class="text-2xl font-bold text-gray-900 mb-2">Oops! Something went wrong</h2>
                <p class="text-gray-600 mb-6">Let's try creating your game again</p>
                <button
                  phx-click="start_game"
                  class="px-8 py-3 bg-gradient-to-r from-green-500 to-blue-500 text-white font-semibold rounded-lg hover:from-green-600 hover:to-blue-600 transition-all shadow-lg"
                >
                  🔄 Try Again
                </button>
              </div>
          <% end %>
        </div>
        
    <!-- Tutorial Overlay -->
        <%= if @show_tutorial and @game_state == :ready do %>
          <div class="bg-gradient-to-r from-purple-500 to-pink-500 rounded-xl shadow-xl p-8 text-white mb-8">
            <div class="text-center">
              <h3 class="text-2xl font-bold mb-4">
                <%= case @tutorial_step do %>
                  <% 1 -> %>
                    🎯 Welcome to Rachel!
                  <% 2 -> %>
                    🃏 How to Play
                  <% 3 -> %>
                    ✨ Special Cards
                  <% 4 -> %>
                    🏆 Ready to Win?
                <% end %>
              </h3>

              <%= case @tutorial_step do %>
                <% 1 -> %>
                  <p class="text-lg mb-6">
                    Rachel is a strategic card game where you try to be the first to empty your hand.
                    Match suits or ranks, use special cards strategically, and outsmart your opponents!
                  </p>
                <% 2 -> %>
                  <div class="text-left max-w-2xl mx-auto mb-6">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div class="bg-white/20 rounded-lg p-4">
                        <h4 class="font-semibold mb-2">🎯 Basic Rules</h4>
                        <ul class="text-sm space-y-1">
                          <li>• Match the suit or rank</li>
                          <li>• Draw if you can't play</li>
                          <li>• First to empty hand wins</li>
                        </ul>
                      </div>
                      <div class="bg-white/20 rounded-lg p-4">
                        <h4 class="font-semibold mb-2">🤖 AI Opponents</h4>
                        <ul class="text-sm space-y-1">
                          <li>• Each has unique personality</li>
                          <li>• Different strategies</li>
                          <li>• Challenging but fair</li>
                        </ul>
                      </div>
                    </div>
                  </div>
                <% 3 -> %>
                  <div class="text-left max-w-2xl mx-auto mb-6">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <div class="bg-white/20 rounded-lg p-3">
                        <span class="font-bold">2️⃣ Twos:</span> Next player draws 2 cards
                      </div>
                      <div class="bg-white/20 rounded-lg p-3">
                        <span class="font-bold">7️⃣ Sevens:</span> Skip next player's turn
                      </div>
                      <div class="bg-white/20 rounded-lg p-3">
                        <span class="font-bold">🃏 Black Jacks:</span> 5 card penalty
                      </div>
                      <div class="bg-white/20 rounded-lg p-3">
                        <span class="font-bold">♥️♦️ Red Jacks:</span> Cancel black jacks
                      </div>
                    </div>
                  </div>
                <% 4 -> %>
                  <p class="text-lg mb-6">
                    You're all set! Your game is ready with smart AI opponents.
                    The interface will guide you - just click on cards to select them,
                    then "Play Cards" to make your move. Good luck! 🍀
                  </p>
              <% end %>

              <div class="flex items-center justify-between">
                <div class="flex space-x-2">
                  <%= for step <- 1..4 do %>
                    <div class={[
                      "w-3 h-3 rounded-full",
                      if(step <= @tutorial_step, do: "bg-white", else: "bg-white/30")
                    ]}>
                    </div>
                  <% end %>
                </div>

                <div class="flex gap-4">
                  <button
                    phx-click="skip_tutorial"
                    class="px-4 py-2 text-white/80 hover:text-white transition-colors"
                  >
                    Skip Tutorial
                  </button>
                  <%= if @tutorial_step < 4 do %>
                    <button
                      phx-click="next_tutorial_step"
                      class="px-6 py-2 bg-white text-purple-600 font-semibold rounded-lg hover:bg-gray-100 transition-colors"
                    >
                      Next →
                    </button>
                  <% else %>
                    <a
                      href={~p"/game/#{@game_id}"}
                      class="px-6 py-2 bg-white text-purple-600 font-semibold rounded-lg hover:bg-gray-100 transition-colors"
                    >
                      Let's Play! 🎮
                    </a>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Quick Tips -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="bg-white rounded-lg shadow-md p-6 text-center">
            <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span class="text-2xl">⚡</span>
            </div>
            <h3 class="font-semibold text-gray-900 mb-2">Instant Start</h3>
            <p class="text-sm text-gray-600">
              No account needed. Jump straight into a game with smart AI opponents.
            </p>
          </div>

          <div class="bg-white rounded-lg shadow-md p-6 text-center">
            <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span class="text-2xl">🧠</span>
            </div>
            <h3 class="font-semibold text-gray-900 mb-2">Learn by Playing</h3>
            <p class="text-sm text-gray-600">
              The game guides you through each move. Perfect for beginners!
            </p>
          </div>

          <div class="bg-white rounded-lg shadow-md p-6 text-center">
            <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span class="text-2xl">🎯</span>
            </div>
            <h3 class="font-semibold text-gray-900 mb-2">Strategic Fun</h3>
            <p class="text-sm text-gray-600">
              Easy to learn, but with deep strategy to master over time.
            </p>
          </div>
        </div>
        
    <!-- Back to home link -->
        <div class="text-center mt-8">
          <.link navigate={~p"/"} class="text-gray-500 hover:text-gray-700 transition-colors">
            ← Back to homepage
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp create_quick_game(player_id, player_name) do
    alias Rachel.Games.GameManager

    # Create AI players with beginner-friendly personalities
    ai_players = [
      EnhancedAIPlayer.new_ai_player("Friendly Charlie", :conservative),
      EnhancedAIPlayer.new_ai_player("Helpful Sam", :strategic)
    ]

    # Use GameManager to properly create and join the game
    case GameManager.create_and_join_game(player_id, player_name) do
      {:ok, game_id} ->
        # Add AI players
        Enum.each(ai_players, fn ai_player ->
          GameServer.add_ai_player(game_id, ai_player.name)
        end)

        # Start the game
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
end
