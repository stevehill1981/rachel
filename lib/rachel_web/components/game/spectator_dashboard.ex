defmodule RachelWeb.Components.Game.SpectatorDashboard do
  @moduledoc """
  Enhanced spectator dashboard with live commentary and advanced viewing features.
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  alias Rachel.Games.Commentary

  attr :game, :map, required: true
  attr :current_player, :any, required: true
  attr :commentary_feed, :list, default: []
  attr :show_cards, :boolean, default: false
  attr :show_statistics, :boolean, default: false

  def spectator_dashboard(assigns) do
    assigns = assign(assigns, :excitement_level, Commentary.get_excitement_level(assigns.game))

    ~H"""
    <div class="spectator-dashboard space-y-6" phx-hook="SpectatorDashboard" id="spectator-dashboard">
      <!-- Header with spectator controls -->
      <div class="flex items-center justify-between bg-gradient-to-r from-blue-600 to-purple-600 p-4 rounded-xl text-white">
        <div class="flex items-center space-x-3">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
            />
          </svg>
          <h2 class="text-xl font-bold">Spectator Mode</h2>
          <.excitement_indicator level={@excitement_level} />
        </div>

        <div class="flex space-x-2">
          <.spectator_toggle
            icon="cards"
            active={@show_cards}
            label="Show Cards"
            event="toggle_cards"
          />
          <.spectator_toggle
            icon="stats"
            active={@show_statistics}
            label="Statistics"
            event="toggle_stats"
          />
        </div>
      </div>
      
    <!-- Live Commentary Feed -->
      <div class="bg-white/10 backdrop-blur rounded-xl p-4">
        <h3 class="text-lg font-semibold text-white mb-3 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 3v10a2 2 0 002 2h6a2 2 0 002-2V7M7 7h10"
            />
          </svg>
          Live Commentary
        </h3>
        <.commentary_feed feed={@commentary_feed} excitement_level={@excitement_level} />
      </div>
      
    <!-- Current Game Status -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Current Turn Info -->
        <div class="bg-white/10 backdrop-blur rounded-xl p-4">
          <h3 class="text-lg font-semibold text-white mb-3">Current Turn</h3>
          <%= if @current_player do %>
            <.current_turn_display player={@current_player} game={@game} />
          <% else %>
            <p class="text-gray-300">Game not in progress</p>
          <% end %>
        </div>
        
    <!-- Game Statistics -->
        <%= if @show_statistics do %>
          <div class="bg-white/10 backdrop-blur rounded-xl p-4">
            <h3 class="text-lg font-semibold text-white mb-3">Game Stats</h3>
            <.game_statistics game={@game} />
          </div>
        <% end %>
      </div>
      
    <!-- Player Overview -->
      <div class="bg-white/10 backdrop-blur rounded-xl p-4">
        <h3 class="text-lg font-semibold text-white mb-4">Players</h3>
        <.players_overview
          players={@game.players}
          current_player={@current_player}
          show_cards={@show_cards}
        />
      </div>
      
    <!-- Game State Indicators -->
      <.game_state_indicators game={@game} />
    </div>
    """
  end

  attr :level, :atom, required: true

  defp excitement_indicator(assigns) do
    ~H"""
    <span class={[
      "px-2 py-1 rounded-full text-xs font-medium animate-pulse",
      @level == :low && "bg-green-500/20 text-green-200",
      @level == :medium && "bg-yellow-500/20 text-yellow-200",
      @level == :high && "bg-orange-500/20 text-orange-200",
      @level == :extreme && "bg-red-500/20 text-red-200"
    ]}>
      <%= case @level do %>
        <% :low -> %>
          😌 Calm
        <% :medium -> %>
          😊 Interesting
        <% :high -> %>
          😲 Exciting
        <% :extreme -> %>
          🔥 INTENSE!
      <% end %>
    </span>
    """
  end

  attr :icon, :string, required: true
  attr :active, :boolean, required: true
  attr :label, :string, required: true
  attr :event, :string, required: true

  defp spectator_toggle(assigns) do
    ~H"""
    <button
      phx-click={@event}
      class={[
        "px-3 py-2 rounded-lg transition-all duration-200 text-sm font-medium",
        @active && "bg-white/20 text-white ring-2 ring-white/30",
        !@active && "bg-white/10 text-white/70 hover:bg-white/15"
      ]}
      title={@label}
    >
      <%= case @icon do %>
        <% "cards" -> %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
            />
          </svg>
        <% "stats" -> %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
            />
          </svg>
      <% end %>
    </button>
    """
  end

  attr :feed, :list, required: true
  attr :excitement_level, :atom, required: true

  defp commentary_feed(assigns) do
    ~H"""
    <div class="commentary-feed max-h-48 overflow-y-auto space-y-2" id="commentary-feed">
      <%= if Enum.empty?(@feed) do %>
        <p class="text-gray-400 italic">Waiting for game action...</p>
      <% else %>
        <%= for {comment, index} <- Enum.with_index(@feed) do %>
          <div class={
            [
              "p-2 rounded-lg text-sm animation-slide-in",
              # Latest comment highlighted
              index == 0 && "bg-blue-500/20 border border-blue-400/30",
              index > 0 && "bg-white/5"
            ]
          }>
            <span class="text-gray-300 text-xs mr-2">
              {format_timestamp(comment.timestamp)}
            </span>
            <span class="text-white">{comment.text}</span>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :game, :map, required: true

  defp current_turn_display(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-center space-x-3">
        <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
          {String.first(@player.name)}
        </div>
        <div>
          <p class="text-white font-semibold">{@player.name}</p>
          <p class="text-gray-300 text-sm">
            {length(@player.hand)} cards
            <%= if @player.is_ai do %>
              • AI Player 🤖
            <% end %>
          </p>
        </div>
      </div>
      
    <!-- Turn-specific information -->
      <%= if @game.pending_pickups > 0 do %>
        <div class="bg-red-500/20 p-2 rounded-lg">
          <p class="text-red-200 text-sm">
            ⚠️ Must draw {@game.pending_pickups} cards or play a counter
          </p>
        </div>
      <% end %>

      <%= if @game.pending_skips > 0 do %>
        <div class="bg-yellow-500/20 p-2 rounded-lg">
          <p class="text-yellow-200 text-sm">
            ⏭️ Turn will be skipped {@game.pending_skips} times
          </p>
        </div>
      <% end %>

      <%= if Map.get(@game, :nominated_suit) && @game.nominated_suit != :pending do %>
        <div class="bg-purple-500/20 p-2 rounded-lg">
          <p class="text-purple-200 text-sm">
            🎯 Must play {format_suit(@game.nominated_suit)}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :game, :map, required: true

  defp game_statistics(assigns) do
    ~H"""
    <div class="space-y-3 text-sm">
      <%= if Map.has_key?(@game, :stats) do %>
        <div class="flex justify-between">
          <span class="text-gray-300">Total turns:</span>
          <span class="text-white font-medium">{@game.stats.game_stats.total_turns}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-300">Cards played:</span>
          <span class="text-white font-medium">{@game.stats.game_stats.total_cards_played}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-300">Special effects:</span>
          <span class="text-white font-medium">
            {@game.stats.game_stats.special_effects_triggered}
          </span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-300">Direction changes:</span>
          <span class="text-white font-medium">{@game.stats.game_stats.direction_changes}</span>
        </div>
      <% else %>
        <p class="text-gray-400">Statistics not available</p>
      <% end %>
    </div>
    """
  end

  attr :players, :list, required: true
  attr :current_player, :any, required: true
  attr :show_cards, :boolean, required: true

  defp players_overview(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <%= for player <- @players do %>
        <div class={[
          "p-3 rounded-lg border transition-all duration-200",
          @current_player && @current_player.id == player.id &&
            "bg-blue-500/20 border-blue-400 ring-2 ring-blue-400/30",
          (!@current_player || @current_player.id != player.id) && "bg-white/5 border-gray-600"
        ]}>
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center space-x-2">
              <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center text-white text-sm font-bold">
                {String.first(player.name)}
              </div>
              <div>
                <p class="text-white font-medium">{player.name}</p>
                <p class="text-gray-400 text-xs">
                  {length(player.hand)} cards
                  <%= if player.is_ai do %>
                    • AI
                  <% end %>
                </p>
              </div>
            </div>

            <%= if @current_player && @current_player.id == player.id do %>
              <span class="px-2 py-1 bg-blue-500 text-white rounded text-xs font-medium animate-pulse">
                Current
              </span>
            <% end %>
          </div>

          <%= if @show_cards and length(player.hand) > 0 do %>
            <div class="mt-2">
              <div class="grid grid-cols-6 gap-1">
                <%= for {card, idx} <- Enum.with_index(Enum.take(player.hand, 12)) do %>
                  <.playing_card
                    card={card}
                    index={idx}
                    player_id={player.id}
                    context="spectator-cards"
                    selected={false}
                    disabled={true}
                    class="transform scale-50 origin-center"
                  />
                <% end %>
                <%= if length(player.hand) > 12 do %>
                  <div class="flex items-center justify-center text-gray-400 text-xs">
                    +{length(player.hand) - 12}
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :game, :map, required: true

  defp game_state_indicators(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-3">
      <!-- Game Direction -->
      <div class="flex items-center space-x-2 bg-white/10 px-3 py-2 rounded-lg">
        <span class="text-gray-300 text-sm">Direction:</span>
        <span class="text-white font-medium text-sm">
          <%= if @game.direction == :clockwise do %>
            ↻ Clockwise
          <% else %>
            ↺ Counter-clockwise
          <% end %>
        </span>
      </div>
      
    <!-- Deck Size -->
      <div class="flex items-center space-x-2 bg-white/10 px-3 py-2 rounded-lg">
        <span class="text-gray-300 text-sm">Deck:</span>
        <span class="text-white font-medium text-sm">
          {Map.get(@game.deck || %{}, :cards, []) |> length()} cards
        </span>
      </div>
      
    <!-- Game Status -->
      <div class="flex items-center space-x-2 bg-white/10 px-3 py-2 rounded-lg">
        <span class="text-gray-300 text-sm">Status:</span>
        <span class={[
          "font-medium text-sm capitalize",
          @game.status == :playing && "text-green-400",
          @game.status == :waiting && "text-yellow-400",
          @game.status == :finished && "text-blue-400"
        ]}>
          {@game.status}
        </span>
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} -> Calendar.strftime(timestamp, "%H:%M:%S")
      _ -> "00:00:00"
    end
  end

  defp format_suit(:hearts), do: "Hearts ♥"
  defp format_suit(:diamonds), do: "Diamonds ♦"
  defp format_suit(:clubs), do: "Clubs ♣"
  defp format_suit(:spades), do: "Spades ♠"
  defp format_suit(suit), do: to_string(suit)
end
