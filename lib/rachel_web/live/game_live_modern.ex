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
        <div class="max-w-7xl mx-auto flex justify-between items-center">
          <h1 class="text-3xl font-bold text-white tracking-wide">
            Rachel Card Game
          </h1>

          <div class="flex gap-2">
            <button
              phx-click="show_save_modal"
              class="px-4 py-2 bg-white/10 backdrop-blur text-white rounded-lg hover:bg-white/20 transition-colors"
            >
              💾 Save
            </button>
            <button
              phx-click="show_load_modal"
              class="px-4 py-2 bg-white/10 backdrop-blur text-white rounded-lg hover:bg-white/20 transition-colors"
            >
              📁 Load
            </button>
            <button
              phx-click="export_game"
              class="px-4 py-2 bg-white/10 backdrop-blur text-white rounded-lg hover:bg-white/20 transition-colors"
            >
              📤 Export
            </button>
          </div>
        </div>
      </header>
      
    <!-- Flash Messages -->
      <%= if Phoenix.Flash.get(@flash, :info) do %>
        <div class="notification-enter fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 bg-green-500 text-white rounded-lg shadow-lg">
          {Phoenix.Flash.get(@flash, :info)}
        </div>
      <% end %>

      <%= if Phoenix.Flash.get(@flash, :error) do %>
        <div class="notification-enter fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 bg-red-500 text-white rounded-lg shadow-lg">
          {Phoenix.Flash.get(@flash, :error)}
        </div>
      <% end %>
      
    <!-- Main Game Area -->
      <main class="relative z-10 p-4 max-w-7xl mx-auto">
        <!-- Game Status Bar -->
        <div class="mb-8">
          <.game_status game={@game} />
        </div>
        
    <!-- Game Table -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <!-- Players List -->
          <div class="bg-white/10 backdrop-blur rounded-2xl p-6">
            <h2 class="text-xl font-bold text-white mb-4">Players</h2>
            <div class="space-y-3">
              <%= for {player, idx} <- Enum.with_index(@game.players) do %>
                <.player_card
                  player={player}
                  is_current={idx == @game.current_player_index}
                  card_count={length(player.hand)}
                />
              <% end %>
            </div>
          </div>
          
    <!-- Current Card Display -->
          <div class="flex items-center justify-center">
            <.current_card_display card={@game.current_card} />
          </div>
          
    <!-- Game Info -->
          <div class="bg-white/10 backdrop-blur rounded-2xl p-6">
            <h2 class="text-xl font-bold text-white mb-4">Game Info</h2>
            <div class="space-y-4 text-white">
              <%= if @show_ai_thinking do %>
                <div class="ai-thinking">
                  AI is thinking...
                </div>
              <% end %>

              <%= if length(@game.winners) > 0 do %>
                <div class="p-4 bg-green-500/20 rounded-lg">
                  <h3 class="font-bold mb-2">🎉 Winners</h3>
                  <p>{Enum.join(@game.winners, ", ")}</p>
                </div>
              <% end %>

              <%= if @game.stats do %>
                <div class="text-sm space-y-2">
                  <p>Turn: {@game.stats.game_stats.total_turns}</p>
                  <p>Cards Played: {@game.stats.game_stats.total_cards_played}</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Player Hand -->
        <%= if current_player(@game) && current_player(@game).id == @player_id && @player_id not in @game.winners do %>
          <div class="bg-white/10 backdrop-blur rounded-2xl p-6">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-bold text-white">Your Hand</h2>
              <div class="flex gap-2">
                <%= if length(@selected_cards) > 0 do %>
                  <button
                    phx-click="play_cards"
                    class="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors font-semibold"
                  >
                    Play {length(@selected_cards)} Card(s)
                  </button>
                <% end %>

                <%= if !Game.has_valid_play?(@game, current_player(@game)) do %>
                  <button
                    phx-click="draw_card"
                    class="px-6 py-2 bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors font-semibold"
                  >
                    Draw {max(1, @game.pending_pickups)} Card(s)
                  </button>
                <% end %>
              </div>
            </div>

            <div class="flex flex-wrap gap-3">
              <%= for {card, idx} <- Enum.with_index(current_player(@game).hand) do %>
                <.playing_card
                  card={card}
                  selected={idx in @selected_cards}
                  disabled={
                    !can_select_card?(@game, card, @selected_cards, current_player(@game).hand)
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
        <%= if @player_id in @game.winners do %>
          <div class="winner-celebration">
            <div class="fixed inset-0 flex items-center justify-center z-50">
              <div class="bg-white rounded-2xl p-12 shadow-2xl text-center max-w-md animate-bounce-in">
                <h2 class="text-4xl font-bold mb-4">🎉 You Won! 🎉</h2>
                <p class="text-gray-600 mb-6">
                  Congratulations on your victory! You can watch the other players finish the game.
                </p>
                <button
                  phx-click="acknowledge_win"
                  class="px-8 py-3 bg-gradient-to-r from-green-500 to-blue-500 text-white rounded-lg font-semibold hover:opacity-90 transition-opacity"
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
      
    <!-- Modals -->
      <%= if @show_save_modal do %>
        <div class="fixed inset-0 bg-black/50 backdrop-blur flex items-center justify-center z-50">
          <div class="bg-white rounded-2xl p-8 shadow-2xl max-w-md w-full mx-4">
            <h3 class="text-2xl font-bold mb-6">Save Game</h3>
            <form phx-submit="save_game">
              <input
                type="text"
                name="save_name"
                placeholder="Enter save name..."
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
              <div class="flex gap-3 mt-6">
                <button
                  type="submit"
                  class="flex-1 px-4 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors font-semibold"
                >
                  Save
                </button>
                <button
                  type="button"
                  phx-click="hide_save_modal"
                  class="flex-1 px-4 py-3 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 transition-colors font-semibold"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @show_load_modal do %>
        <div class="fixed inset-0 bg-black/50 backdrop-blur flex items-center justify-center z-50">
          <div class="bg-white rounded-2xl p-8 shadow-2xl max-w-4xl w-full mx-4 max-h-[80vh] overflow-y-auto">
            <h3 class="text-2xl font-bold mb-6">Load Game</h3>

            <%= if Enum.empty?(@saved_games) do %>
              <p class="text-gray-500 text-center py-8">No saved games found.</p>
            <% else %>
              <div class="space-y-3">
                <%= for save <- @saved_games do %>
                  <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                    <div>
                      <div class="font-semibold">{save.name}</div>
                      <div class="text-sm text-gray-600">
                        {save.players} players • {format_date(save.saved_at)}
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <button
                        phx-click="load_game"
                        phx-value-save_name={save.name}
                        class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors text-sm font-semibold"
                      >
                        Load
                      </button>
                      <button
                        phx-click="delete_save"
                        phx-value-save_name={save.name}
                        onclick="return confirm('Delete this save?')"
                        class="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors text-sm font-semibold"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="mt-6">
              <button
                phx-click="hide_load_modal"
                class="w-full px-4 py-3 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 transition-colors font-semibold"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Confetti for winners -->
      <div id="confetti-container" class="winner-celebration"></div>
    </div>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
