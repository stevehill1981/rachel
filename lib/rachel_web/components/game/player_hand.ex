defmodule RachelWeb.Components.Game.PlayerHand do
  @moduledoc """
  Player hand display and interaction component
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  alias Rachel.Games.Game

  attr :game, :map, required: true
  attr :player_id, :string, required: true
  attr :selected_cards, :list, default: []
  attr :current_player, :any, required: true
  attr :is_spectator, :boolean, default: false
  attr :commentary_feed, :list, default: []
  attr :show_cards, :boolean, default: false
  attr :show_statistics, :boolean, default: false

  def player_hand(assigns) do
    assigns = assign(assigns, :player, find_player(assigns.game, assigns.player_id))

    ~H"""
    <%= if @game.status == :finished do %>
      <div
        id={"player-hand-finished-#{@player_id}"}
        class="theme-shadow-lg p-6 text-center rounded-2xl border-2"
        style="background-color: var(--theme-success) !important; border-color: var(--theme-success); opacity: 0.95;"
      >
        <%= if @player_id in @game.winners do %>
          <div class="text-xl font-bold mb-2" style="color: var(--theme-success-text);">
            🎉 You Won! 🎉
          </div>
          <div style="color: var(--theme-success-text); opacity: 0.9;">
            You finished in position #{(Enum.find_index(@game.winners, &(&1 == @player_id)) || 0) +
              1}
          </div>
        <% else %>
          <div class="text-xl font-bold mb-2" style="color: var(--theme-success-text);">
            Game Over
          </div>
          <div style="color: var(--theme-success-text); opacity: 0.9;">
            You were the last player remaining
          </div>
        <% end %>
        <button
          id="return-to-lobby-btn"
          phx-click="return_to_lobby"
          phx-hook="ClickDebounce"
          data-debounce="1000"
          class="mt-4 px-6 py-2 rounded-lg transition-colors font-medium relative z-50 cursor-pointer"
          style="background-color: var(--theme-button-primary); color: var(--theme-success-text); pointer-events: auto;"
        >
          Return Home
        </button>
      </div>
    <% else %>
      <%= if @player && @player_id not in @game.winners do %>
        <div
          id={"player-hand-active-#{@player_id}"}
          class="theme-card backdrop-blur rounded-2xl p-6"
          style="background-color: var(--theme-bg-glass);"
        >
          <.play_button selected_cards={@selected_cards} />
          <.game_messages game={@game} current_player={@current_player} player_id={@player_id} />
          <.hand_display
            player={@player}
            game={@game}
            player_id={@player_id}
            selected_cards={@selected_cards}
            current_player={@current_player}
          />
        </div>
      <% else %>
        <div
          id={"player-hand-waiting-#{@player_id}"}
          class="backdrop-blur rounded-2xl p-6 text-center border-2"
          style="background-color: var(--theme-success) !important; border-color: var(--theme-success); opacity: 0.95;"
        >
          <div class="text-lg font-bold mb-2" style="color: var(--theme-success-text);">
            🎉 You Won! 🎉
          </div>
          <div style="color: var(--theme-success-text); opacity: 0.9;">
            Waiting for other players to finish...
          </div>
          <div class="text-sm mt-2" style="color: var(--theme-success-text); opacity: 0.8;">
            Position: #{(Enum.find_index(@game.winners, &(&1 == @player_id)) || 0) + 1}
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp find_player(game, player_id) do
    Enum.find(game.players, fn p -> p.id == player_id end)
  end

  attr :selected_cards, :list, required: true

  defp play_button(assigns) do
    ~H"""
    <%= if length(@selected_cards) > 0 do %>
      <div class="flex flex-col items-center mb-4 space-y-2">
        <!-- Multi-card selection indicator -->
        <%= if length(@selected_cards) > 1 do %>
          <div class="flex space-x-1">
            <%= for i <- 1..length(@selected_cards) do %>
              <div
                class="w-2 h-2 bg-blue-400 rounded-full animate-pulse"
                style={"animation-delay: #{(i-1) * 100}ms"}
              >
              </div>
            <% end %>
          </div>
          <div class="text-xs text-blue-300 font-medium">
            {length(@selected_cards)} cards selected
          </div>
        <% end %>
        
    <!-- Main play button -->
        <button
          id="play-cards-btn"
          phx-click="play_cards"
          phx-hook="ClickDebounce"
          data-debounce="500"
          class="px-8 py-3 rounded-xl font-bold transition-all duration-200 shadow-lg active:scale-95 touch-manipulation min-h-[48px] min-w-[120px]"
          style={
            if length(@selected_cards) == 1 do
              "background-color: var(--theme-button-success); color: var(--theme-text-inverse);"
            else
              "background-color: var(--theme-button-primary); color: var(--theme-text-inverse); box-shadow: 0 0 0 2px var(--theme-primary-light);"
            end
          }
        >
          <%= if length(@selected_cards) == 1 do %>
            <span class="flex items-center space-x-2">
              <span>▶</span>
              <span>Play Card</span>
            </span>
          <% else %>
            <span class="flex items-center space-x-2">
              <span>🃏</span>
              <span>Play {length(@selected_cards)} Cards</span>
            </span>
          <% end %>
        </button>
      </div>
    <% end %>
    """
  end

  attr :game, :map, required: true
  attr :current_player, :any, required: true
  attr :player_id, :string, required: true

  defp game_messages(assigns) do
    ~H"""
    <%= if @current_player && @current_player.id == @player_id && @game.pending_pickups > 0 && !Game.has_valid_play?(@game, @current_player) && @game.status == :playing do %>
      <div
        id="drawing-cards-message"
        class="mb-4 p-3 rounded-lg animate-pulse"
        style="background-color: var(--theme-error); opacity: 0.2; border: 1px solid var(--theme-error);"
      >
        <div class="text-center font-semibold theme-text-primary">
          Drawing {@game.pending_pickups} cards...
        </div>
      </div>
    <% end %>

    <%= if @current_player && @current_player.id != @player_id && @game.status == :playing do %>
      <div
        id="waiting-turn-message"
        class="mb-4 p-3 rounded-lg"
        style="background-color: var(--theme-bg-tertiary); border: 1px solid var(--theme-card-border);"
      >
        <div class="text-center font-semibold theme-text-secondary">
          Waiting for {@current_player.name}'s turn...
        </div>
      </div>
    <% end %>
    """
  end

  attr :player, :any, required: true
  attr :game, :map, required: true
  attr :player_id, :string, required: true
  attr :selected_cards, :list, required: true
  attr :current_player, :any, required: true

  defp hand_display(assigns) do
    assigns =
      assign(assigns, :hand_size, if(assigns.player, do: length(assigns.player.hand), else: 0))

    ~H"""
    <%= if @player do %>
      <!-- Mobile: Horizontal scroll, Desktop: Grid -->
      <div class={
        [
          # Mobile: horizontal scrolling container
          "flex overflow-x-auto gap-3 pb-4 snap-x snap-mandatory lg:hidden",
          # Hide scrollbar on mobile
          "scrollbar-hide",
          # Padding for scroll snap
          "px-2"
        ]
      }>
        <%= for {card, idx} <- Enum.with_index(@player.hand) do %>
          <div class="flex-shrink-0 snap-start">
            <.playing_card
              card={card}
              index={idx}
              player_id={@player_id}
              context="mobile"
              selected={idx in @selected_cards}
              disabled={
                @current_player == nil ||
                  @current_player.id != @player_id ||
                  !RachelWeb.GameLive.EventHandlers.can_select_card?(
                    @game,
                    card,
                    @selected_cards,
                    @player.hand
                  )
              }
              phx-click="select_card"
              phx-value-index={idx}
            />
          </div>
        <% end %>
      </div>
      
    <!-- Desktop: Grid layout -->
      <div class="hidden lg:grid lg:grid-cols-8 gap-2">
        <%= for {card, idx} <- Enum.with_index(@player.hand) do %>
          <div class="flex justify-center">
            <.playing_card
              card={card}
              index={idx}
              player_id={@player_id}
              context="desktop"
              selected={idx in @selected_cards}
              disabled={
                @current_player == nil ||
                  @current_player.id != @player_id ||
                  !RachelWeb.GameLive.EventHandlers.can_select_card?(
                    @game,
                    card,
                    @selected_cards,
                    @player.hand
                  )
              }
              phx-click="select_card"
              phx-value-index={idx}
            />
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end
end
