defmodule RachelWeb.Components.Game.DeckArea do
  @moduledoc """
  Deck and current card display area
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  alias Rachel.Games.Game

  attr :game, :map, required: true
  attr :player_id, :string, required: true
  attr :show_ai_thinking, :boolean, default: false
  attr :current_player, :any, required: true

  def deck_area(assigns) do
    ~H"""
    <div class="relative">
      <!-- AI Thinking Indicator -->
      <%= if @show_ai_thinking && @current_player && @current_player.is_ai do %>
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
                @current_player && @current_player.id == @player_id &&
                  !Game.has_valid_play?(@game, @current_player)
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
    """
  end
end
