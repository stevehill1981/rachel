defmodule RachelWeb.Components.Game.PlayerHand do
  @moduledoc """
  Player hand display and interaction component
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  import RachelWeb.Components.Game.SpectatorDashboard
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
    <%= if @is_spectator do %>
      <.spectator_dashboard
        game={@game}
        current_player={@current_player}
        commentary_feed={@commentary_feed}
        show_cards={@show_cards}
        show_statistics={@show_statistics}
      />
    <% else %>
      <%= if @player && @player_id not in @game.winners do %>
        <div class="bg-white/10 backdrop-blur rounded-2xl p-6">
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
              <div class="w-2 h-2 bg-blue-400 rounded-full animate-pulse" style={"animation-delay: #{(i-1) * 100}ms"}></div>
            <% end %>
          </div>
          <div class="text-xs text-blue-300 font-medium">
            {length(@selected_cards)} cards selected
          </div>
        <% end %>
        
        <!-- Main play button -->
        <button
          phx-click="play_cards"
          class={[
            "px-8 py-3 text-white rounded-xl font-bold transition-all duration-200",
            "shadow-lg active:scale-95 touch-manipulation",
            # Large touch target
            "min-h-[48px] min-w-[120px]",
            # Different colors for single vs multi-card
            length(@selected_cards) == 1 && "bg-green-500 hover:bg-green-600",
            length(@selected_cards) > 1 && "bg-blue-500 hover:bg-blue-600 ring-2 ring-blue-300/50"
          ]}
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
      <div id="drawing-cards-message" class="mb-4 p-3 bg-red-500/20 rounded-lg border border-red-400/30 animate-pulse">
        <div class="text-center text-red-200 font-semibold">
          Drawing {@game.pending_pickups} cards...
        </div>
      </div>
    <% end %>

    <%= if @current_player && @current_player.id != @player_id && @game.status == :playing do %>
      <div id="waiting-turn-message" class="mb-4 p-3 bg-gray-500/20 rounded-lg border border-gray-400/30">
        <div class="text-center text-gray-200 font-semibold">
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
    assigns = assign(assigns, :hand_size, if(assigns.player, do: length(assigns.player.hand), else: 0))
    
    ~H"""
    <%= if @player do %>
      <!-- Mobile: Horizontal scroll, Desktop: Grid -->
      <div class={[
        # Mobile: horizontal scrolling container
        "flex overflow-x-auto gap-3 pb-4 snap-x snap-mandatory lg:hidden",
        # Hide scrollbar on mobile
        "scrollbar-hide",
        # Padding for scroll snap
        "px-2"
      ]}>
        <%= for {card, idx} <- Enum.with_index(@player.hand) do %>
          <div class="flex-shrink-0 snap-start">
            <.playing_card
              card={card}
              index={idx}
              player_id={@player_id}
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

  attr :game, :map, required: true
  attr :current_player, :any, required: true

  defp spectator_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @current_player do %>
        <div class="text-center p-3 bg-yellow-500/20 rounded-lg border border-yellow-400/30">
          <div class="text-yellow-200 font-semibold">
            Current Turn: {@current_player.name}
          </div>
        </div>
      <% end %>

      <%= for player <- @game.players do %>
        <div class="border rounded-lg p-4 bg-white/5">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-lg font-semibold text-white flex items-center">
              {player.name}
              <%= if player.is_ai do %>
                <span class="ml-2 px-2 py-1 text-xs bg-purple-500/20 text-purple-200 rounded">
                  AI
                </span>
              <% end %>
              <%= if @current_player && @current_player.id == player.id do %>
                <span class="ml-2 px-2 py-1 text-xs bg-yellow-500/20 text-yellow-200 rounded">
                  Current Turn
                </span>
              <% end %>
            </h3>
            <span class="text-sm text-gray-300">{length(player.hand)} cards</span>
          </div>

          <div class="grid grid-cols-8 lg:grid-cols-12 gap-1">
            <%= for card <- player.hand do %>
              <div class="flex justify-center">
                <.playing_card
                  card={card}
                  index={0}
                  player_id={player.id}
                  selected={false}
                  disabled={true}
                  class="transform scale-75"
                />
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
