defmodule RachelWeb.GameLive.Modern do
  @moduledoc """
  Modern UI template for the game
  """

  use Phoenix.Component
  import RachelWeb.GameComponents
  alias Rachel.Games.Game

  # Import necessary functions from parent module
  import RachelWeb.GameLive,
    only: [
      current_player: 1,
      can_select_card?: 4
    ]

  def render(assigns) do
    ~H"""
    <div class="game-board min-h-screen">
      <!-- Header -->
      <header class="relative z-10 p-4">
        <div class="max-w-7xl mx-auto">
          <h1 class="text-3xl font-bold text-white tracking-wide text-center">
            Rachel
          </h1>
        </div>
      </header>
      
    <!-- Flash Messages -->
      <%= if Phoenix.Flash.get(@flash, :info) do %>
        <div
          id="flash-info"
          class="notification-enter fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 bg-green-500 text-white rounded-lg shadow-lg"
          phx-click="lv:clear-flash"
          phx-value-key="info"
          phx-hook="AutoHideFlash"
        >
          {Phoenix.Flash.get(@flash, :info)}
        </div>
      <% end %>

      <%= if Phoenix.Flash.get(@flash, :error) do %>
        <div
          id="flash-error"
          class="notification-enter fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 bg-red-500 text-white rounded-lg shadow-lg"
          phx-click="lv:clear-flash"
          phx-value-key="error"
          phx-hook="AutoHideFlash"
        >
          {Phoenix.Flash.get(@flash, :error)}
        </div>
      <% end %>
      
    <!-- Main Game Area -->
      <main class="relative z-10 p-4 max-w-7xl mx-auto">
        
    <!-- Players List (Horizontal) -->
        <div class="bg-white/10 backdrop-blur rounded-2xl p-6 mb-8">
          <div class="flex flex-wrap gap-4 justify-center items-center">
            <%= if @game.direction == :clockwise do %>
              <div class="text-white/60 text-2xl direction-indicator">→</div>
            <% else %>
              <div class="text-white/60 text-2xl direction-indicator">←</div>
            <% end %>
            <%= for {player, idx} <- Enum.with_index(@game.players) do %>
              <.player_card_horizontal
                player={player}
                is_current={idx == @game.current_player_index}
                card_count={length(player.hand)}
              />
            <% end %>
            <%= if @game.direction == :clockwise do %>
              <div class="text-white/60 text-2xl direction-indicator">→</div>
            <% else %>
              <div class="text-white/60 text-2xl direction-indicator">←</div>
            <% end %>
          </div>
        </div>
        
    <!-- Deck and Current Card Display -->
        <div class="relative">
          <!-- AI Thinking Indicator -->
          <%= if @show_ai_thinking && current_player(@game) && current_player(@game).is_ai do %>
            <div class="absolute -top-12 left-1/2 -translate-x-1/2 z-20">
              <.ai_thinking_indicator />
            </div>
          <% end %>

          <div class="flex items-center justify-center gap-8 mb-8">
            <!-- Deck -->
            <div class="flex flex-col items-center">
              <div class="w-32 h-44">
                <.deck_display
                  deck_size={Rachel.Games.Deck.size(@game.deck)}
                  can_draw={
                    current_player(@game) && current_player(@game).id == @player_id &&
                      !Game.has_valid_play?(@game, current_player(@game))
                  }
                />
              </div>
            </div>
            
    <!-- Current Card -->
            <div class="flex flex-col items-center">
              <div class="w-32 h-44">
                <.current_card_display
                  card={@game.current_card}
                  discard_pile_size={length(@game.discard_pile)}
                  pending_pickups={@game.pending_pickups}
                  pending_skips={@game.pending_skips}
                />
              </div>
            </div>
          </div>
        </div>
        
    <!-- Player Hand -->
        <%= if @player_id not in @game.winners do %>
          <div class="bg-white/10 backdrop-blur rounded-2xl p-6">
            <%= if length(@selected_cards) > 0 do %>
              <div class="flex justify-center mb-4">
                <button
                  phx-click="play_cards"
                  class="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors font-semibold"
                >
                  Play {length(@selected_cards)} Card{if length(@selected_cards) == 1,
                    do: "",
                    else: "s"}
                </button>
              </div>
            <% end %>
            
    <!-- Game Messages -->
            <%= if current_player(@game) && current_player(@game).id == @player_id && @game.pending_pickups > 0 && !Game.has_valid_play?(@game, current_player(@game)) && @game.status == :playing do %>
              <div class="mb-4 p-3 bg-red-500/20 rounded-lg border border-red-400/30 animate-pulse game-message">
                <div class="text-center text-red-200 font-semibold">
                  Drawing {@game.pending_pickups} cards...
                </div>
              </div>
            <% end %>

            <%= if current_player(@game) && current_player(@game).id != @player_id && @game.status == :playing do %>
              <div class="mb-4 p-3 bg-gray-500/20 rounded-lg border border-gray-400/30 game-message">
                <div class="text-center text-gray-200 font-semibold">
                  Waiting for {current_player(@game).name}'s turn...
                </div>
              </div>
            <% end %>

            <%= if current_player(@game) && current_player(@game).id == @player_id && !Game.has_valid_play?(@game, current_player(@game)) && @game.pending_pickups == 0 && @game.status == :playing do %>
              <div class="mb-4 p-3 bg-yellow-500/20 rounded-lg border border-yellow-400/30 game-message">
                <div class="text-center text-yellow-200 font-semibold">
                  No valid moves - Click the deck to draw a card
                </div>
              </div>
            <% end %>
            
    <!-- Nominated Suit Message -->
            <%= if @game.nominated_suit && @game.nominated_suit != :pending && current_player(@game) && current_player(@game).id == @player_id do %>
              <div class="mb-4 p-3 bg-purple-500/20 rounded-lg border border-purple-400/30 game-message">
                <div class="text-center text-purple-200 font-semibold">
                  Must play
                  <%= case @game.nominated_suit do %>
                    <% :hearts -> %>
                      <span class="text-red-400">♥ Hearts</span>
                    <% :diamonds -> %>
                      <span class="text-red-400">♦ Diamonds</span>
                    <% :clubs -> %>
                      <span class="text-gray-300">♣ Clubs</span>
                    <% :spades -> %>
                      <span class="text-gray-300">♠ Spades</span>
                  <% end %>
                  or an Ace
                </div>
              </div>
            <% end %>

            <div class="flex flex-wrap gap-3 justify-center">
              <%= for {card, idx} <- Enum.with_index(Enum.find(@game.players, fn p -> p.id == @player_id end).hand) do %>
                <.playing_card
                  card={card}
                  selected={idx in @selected_cards}
                  disabled={
                    current_player(@game) == nil ||
                      current_player(@game).id != @player_id ||
                      !can_select_card?(
                        @game,
                        card,
                        @selected_cards,
                        Enum.find(@game.players, fn p -> p.id == @player_id end).hand
                      )
                  }
                  index={idx}
                  phx-click="select_card"
                  phx-value-index={idx}
                />
              <% end %>
            </div>
          </div>
        <% end %>
        
    <!-- Winner Celebration -->
        <%= if @show_winner_banner do %>
          <div class="winner-celebration" phx-hook="WinnerCelebration" id="winner-celebration">
            <div class="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50">
              <div class="bg-white rounded-2xl p-12 shadow-2xl text-center max-w-md mx-4 animate-bounce-in">
                <h2 class="text-4xl font-bold mb-4">🎉 You Won! 🎉</h2>
                <p class="text-gray-600 mb-6">
                  Congratulations on your victory! Click to continue watching the other players finish the game.
                </p>
                <button
                  id="acknowledge-win-button"
                  phx-click="acknowledge_win"
                  class="px-8 py-3 bg-gradient-to-r from-green-500 to-blue-500 text-white rounded-lg font-semibold hover:opacity-90 transition-opacity"
                  phx-hook="SoundEffect"
                  data-sound="win"
                >
                  Continue Watching
                </button>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Suit Nomination -->
        <%= if @game.nominated_suit == :pending && current_player(@game) && current_player(@game).id == @player_id do %>
          <.suit_selector />
        <% end %>
      </main>
      
    <!-- Confetti for winners -->
      <%= if @show_winner_banner do %>
        <div id="confetti-container" class="winner-celebration" phx-hook="WinnerCelebration"></div>
      <% end %>
    </div>
    """
  end
end
