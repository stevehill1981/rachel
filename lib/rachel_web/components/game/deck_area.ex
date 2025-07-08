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
  attr :layout, :string, default: "default"

  def deck_area(assigns) do
    # With normalized game data, we can access fields directly
    game = assigns.game

    assigns =
      assigns
      |> assign_new(:deck_size, fn ->
        Rachel.Games.Deck.size(game.deck)
      end)
      |> assign_new(:discard_pile_size, fn ->
        length(game.discard_pile)
      end)
      |> assign_new(:pending_pickups, fn ->
        game.pending_pickups
      end)
      |> assign_new(:pending_skips, fn ->
        game.pending_skips
      end)
      |> assign_new(:current_card, fn ->
        game.current_card
      end)
      |> assign_new(:can_draw, fn ->
        current_player = assigns.current_player
        player_id = assigns.player_id

        if current_player && current_player.id == player_id do
          !Game.has_valid_play?(game, current_player)
        else
          false
        end
      end)

    ~H"""
    <div class="relative">
      <!-- AI Thinking Indicator -->
      <%= if @show_ai_thinking && @current_player && Map.get(@current_player, :is_ai) do %>
        <div class="absolute -top-12 left-1/2 -translate-x-1/2 z-20">
          <.ai_thinking_indicator />
        </div>
      <% end %>

      <div class="flex items-center justify-center gap-4 md:gap-8">
        <!-- Deck -->
        <div class="flex flex-col items-center">
          <div class="text-xs font-medium theme-text-tertiary mb-2 opacity-70">Deck</div>
          <div class="w-24 h-32 md:w-32 md:h-44">
            <.deck_display
              deck_size={@deck_size}
              can_draw={@can_draw}
              player_id={@player_id}
              layout={@layout}
            />
          </div>
        </div>
        
    <!-- Current Card -->
        <div class="flex flex-col items-center">
          <div class="text-xs font-medium theme-text-tertiary mb-2 opacity-70">Current Card</div>
          <div class="w-24 h-32 md:w-32 md:h-44">
            <.current_card_display
              card={@current_card}
              discard_pile_size={@discard_pile_size}
              pending_pickups={@pending_pickups}
              pending_skips={@pending_skips}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
