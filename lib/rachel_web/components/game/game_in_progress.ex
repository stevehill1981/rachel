defmodule RachelWeb.Components.Game.GameInProgress do
  @moduledoc """
  Main game in progress view component
  """
  use Phoenix.Component
  import RachelWeb.Components.Game.{PlayersDisplay, DeckArea, PlayerHand}
  import RachelWeb.GameComponents

  # Import the current_player function from StateManager
  alias RachelWeb.GameLive.StateManager

  attr :game, :map, required: true
  attr :player_id, :string, required: true
  attr :selected_cards, :list, default: []
  attr :show_ai_thinking, :boolean, default: false
  attr :is_spectator, :boolean, default: false
  attr :commentary_feed, :list, default: []
  attr :spectator_show_cards, :boolean, default: false
  attr :spectator_show_stats, :boolean, default: false

  def game_in_progress(assigns) do
    assigns = assign(assigns, :current_player, StateManager.current_player(assigns.game))

    ~H"""
    <div class="game-layout flex flex-col lg:grid lg:grid-cols-3 lg:grid-rows-3 gap-2 lg:gap-4 min-h-screen lg:min-h-[80vh] page-transition pb-32 lg:pb-0">
      <!-- Top Players - Compact on mobile for more game space -->
      <div class="lg:col-span-3 lg:row-start-1 flex-shrink-0">
        <.players_display game={@game} />
      </div>
      
      <!-- Mobile: Compact middle section with game area and status side by side -->
      <div class="flex lg:hidden gap-2 flex-shrink-0 px-2">
        <!-- Main Game Area -->
        <div class="flex-1 flex items-center justify-center min-h-[200px]">
          <.deck_area
            game={@game}
            player_id={@player_id}
            show_ai_thinking={@show_ai_thinking}
            current_player={@current_player}
          />
        </div>
        
        <!-- Side Game Info - Compact vertical -->
        <div class="w-20 flex flex-col items-center justify-center">
          <.game_status game={@game} />
        </div>
      </div>
      
      <!-- Desktop: Original grid layout -->
      <div class="hidden lg:flex lg:col-start-2 lg:row-start-2 items-center justify-center">
        <.deck_area
          game={@game}
          player_id={@player_id}
          show_ai_thinking={@show_ai_thinking}
          current_player={@current_player}
        />
      </div>
      
      <div class="hidden lg:flex lg:col-start-1 lg:row-start-2 lg:col-start-3 lg:row-start-2 flex-col items-center justify-center">
        <.game_status game={@game} />
      </div>
      
    <!-- Player Hand - Fixed bottom position for easy thumb access -->
      <div class="lg:col-span-3 lg:row-start-3 mt-auto fixed bottom-0 left-0 right-0 lg:relative lg:bottom-auto bg-slate-900/90 backdrop-blur lg:bg-transparent p-2 lg:p-0 z-50">
        <.player_hand
          game={@game}
          player_id={@player_id}
          selected_cards={@selected_cards}
          current_player={@current_player}
          is_spectator={@is_spectator}
          commentary_feed={@commentary_feed}
          show_cards={@spectator_show_cards}
          show_statistics={@spectator_show_stats}
        />
      </div>
      
    <!-- Suit Nomination Modal -->
      <%= if !@is_spectator && Map.get(@game, :nominated_suit) == :pending && @current_player && @current_player.id == @player_id do %>
        <.suit_selector />
      <% end %>
    </div>
    """
  end
end
