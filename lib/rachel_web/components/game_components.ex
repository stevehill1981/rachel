defmodule RachelWeb.GameComponents do
  @moduledoc """
  Game-specific UI components for Rachel card game.
  """
  use Phoenix.Component

  alias Rachel.Games.Card

  @doc """
  Renders a playing card with animations and proper styling.
  """
  attr :card, Card, required: true
  attr :selected, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :index, :integer, default: nil
  attr :player_id, :string, default: nil
  attr :context, :string, default: nil
  attr :rest, :global

  def playing_card(assigns) do
    ~H"""
    <button
      type="button"
      class={
        [
          "playing-card relative rounded-lg border-2 theme-shadow-lg overflow-hidden",
          "transition-all duration-300 transform flex items-center justify-center",
          # Smaller on mobile, larger on desktop
          "min-h-[100px] min-w-[70px] sm:min-h-[120px] sm:min-w-[85px]",
          # Responsive sizing - smaller on mobile
          "w-16 h-24 sm:w-20 sm:h-28",
          # Responsive text sizing
          "text-lg sm:text-2xl font-bold",
          # Optimize for touch
          "touch-manipulation",
          @selected && "selected -translate-y-2 sm:-translate-y-4 scale-105",
          @disabled && "opacity-50 cursor-not-allowed",
          # Touch feedback
          !@disabled && "active:scale-95 cursor-pointer touch-card",
          # Hover for non-touch
          !@disabled && "hover:shadow-xl hover:-translate-y-2",
          special_card?(@card) && "special-card-glow"
        ]
      }
      style={
        "background: var(--theme-card-gradient); border-color: var(--theme-card-border);" <>
        if @selected do
          " box-shadow: 0 0 0 4px var(--theme-primary), var(--theme-shadow-lg);"
        else
          " box-shadow: var(--theme-shadow-md);"
        end
      }
      disabled={@disabled}
      data-effect={card_effect_text(@card)}
      data-rank={rank_to_string(@card.rank)}
      data-suit={Atom.to_string(@card.suit)}
      aria-label={card_aria_label(@card, @selected)}
      aria-pressed={(@selected && "true") || "false"}
      id={
        case {@player_id, @index, @context} do
          {nil, nil, _} ->
            nil

          {player_id, index, context} when not is_nil(player_id) and not is_nil(index) ->
            context_suffix = if context, do: "-#{context}", else: ""
            "touch-card-#{player_id}-#{index}#{context_suffix}"

          {nil, index, context} when not is_nil(index) ->
            context_suffix = if context, do: "-#{context}", else: ""
            "touch-card-#{index}#{context_suffix}"

          _ ->
            nil
        end
      }
      phx-hook="TouchCard"
      data-card-index={@index}
      {@rest}
    >
      <!-- Card pattern overlay -->
      <div
        class="absolute inset-0 pointer-events-none opacity-30"
        style="background-image: var(--theme-card-pattern); background-size: cover;"
      >
      </div>
      
    <!-- Card corner decorations -->
      <div
        class="absolute top-1 left-1 text-xs font-bold opacity-70"
        style={
          (card_red?(@card) && "color: var(--theme-card-red);") || "color: var(--theme-card-black);"
        }
      >
        {rank_to_string(@card.rank)}
      </div>
      <div
        class="absolute top-1 right-1 text-xs opacity-70"
        style={
          (card_red?(@card) && "color: var(--theme-card-red);") || "color: var(--theme-card-black);"
        }
      >
        {suit_to_symbol(@card.suit)}
      </div>
      <div
        class="absolute bottom-1 left-1 text-xs opacity-70 rotate-180"
        style={
          (card_red?(@card) && "color: var(--theme-card-red);") || "color: var(--theme-card-black);"
        }
      >
        {suit_to_symbol(@card.suit)}
      </div>
      <div
        class="absolute bottom-1 right-1 text-xs font-bold opacity-70 rotate-180"
        style={
          (card_red?(@card) && "color: var(--theme-card-red);") || "color: var(--theme-card-black);"
        }
      >
        {rank_to_string(@card.rank)}
      </div>
      
    <!-- Main card content -->
      <span class={[
        "relative z-10",
        card_red?(@card) && "card-suit-red",
        !card_red?(@card) && "card-suit-black"
      ]}>
        {card_display(@card)}
      </span>
      <%= if @selected do %>
        <span class="absolute top-1 right-1 w-6 h-6 sm:w-5 sm:h-5 bg-blue-500 text-white rounded-full text-xs font-bold flex items-center justify-center animate-bounce-in shadow-lg">
          ✓
        </span>
      <% end %>
      <%= if special_card?(@card) && !@selected do %>
        <span class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-3xl opacity-20 font-bold pointer-events-none">
          {special_icon(@card)}
        </span>
      <% end %>
      <!-- Touch ripple effect container -->
      <span class="touch-ripple absolute inset-0 rounded-lg overflow-hidden pointer-events-none">
      </span>
    </button>
    """
  end

  @doc """
  Renders the current card in play with discard pile stack effect underneath.
  """
  attr :card, Card, default: nil
  attr :discard_pile_size, :integer, default: 0
  attr :pending_pickups, :integer, default: 0
  attr :pending_skips, :integer, default: 0

  def current_card_display(assigns) do
    ~H"""
    <div class="relative w-full h-full">
      <!-- Discard pile stack effect - cards underneath (only show if pile has cards) -->
      <%= if @discard_pile_size > 0 do %>
        <%= for i <- 1..min(@discard_pile_size, 4) do %>
          <div
            class="absolute w-full h-full rounded-2xl theme-shadow-lg"
            style={"background-color: var(--theme-bg-tertiary); border: 1px solid var(--theme-card-border); top: #{(i-1) * 2}px; left: #{(i-1) * 2}px; transform: rotate(#{(i - 2) * 1}deg); z-index: #{5-i};"}
          >
            <div class="w-full h-full flex items-center justify-center text-3xl font-bold theme-text-tertiary">
              ♠
            </div>
          </div>
        <% end %>
      <% end %>
      
    <!-- Main current card -->
      <div
        class="relative w-full h-full rounded-2xl theme-shadow-xl transform hover:rotate-3 transition-transform z-10 overflow-hidden"
        style="background: var(--theme-card-gradient); border: 2px solid var(--theme-card-border);"
      >
        <%= if @card do %>
          <!-- Card pattern overlay -->
          <div
            class="absolute inset-0 pointer-events-none opacity-30"
            style="background-image: var(--theme-card-pattern); background-size: cover;"
          >
          </div>
          
    <!-- Card corner decorations -->
          <div
            class="absolute top-2 left-2 text-sm font-bold opacity-70"
            style={
              (card_red?(@card) && "color: var(--theme-card-red);") ||
                "color: var(--theme-card-black);"
            }
          >
            {rank_to_string(@card.rank)}
          </div>
          <div
            class="absolute top-2 right-2 text-sm opacity-70"
            style={
              (card_red?(@card) && "color: var(--theme-card-red);") ||
                "color: var(--theme-card-black);"
            }
          >
            {suit_to_symbol(@card.suit)}
          </div>
          <div
            class="absolute bottom-2 left-2 text-sm opacity-70 rotate-180"
            style={
              (card_red?(@card) && "color: var(--theme-card-red);") ||
                "color: var(--theme-card-black);"
            }
          >
            {suit_to_symbol(@card.suit)}
          </div>
          <div
            class="absolute bottom-2 right-2 text-sm font-bold opacity-70 rotate-180"
            style={
              (card_red?(@card) && "color: var(--theme-card-red);") ||
                "color: var(--theme-card-black);"
            }
          >
            {rank_to_string(@card.rank)}
          </div>

          <div class="w-full h-full flex flex-col items-center justify-center p-2 relative z-10">
            <div class={[
              "text-4xl font-bold text-center",
              card_red?(@card) && "card-suit-red",
              !card_red?(@card) && "card-suit-black"
            ]}>
              {card_display(@card)}
            </div>
          </div>
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-2xl theme-text-tertiary">
            ?
          </div>
        <% end %>
      </div>
      
    <!-- Pending effects indicators -->
      <%= if @pending_pickups > 0 do %>
        <div class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-8 h-8 flex items-center justify-center text-sm font-bold shadow-lg z-20 animate-pulse">
          +{@pending_pickups}
        </div>
      <% end %>

      <%= if @pending_skips > 0 do %>
        <div class="absolute -top-2 -left-2 bg-yellow-500 text-white rounded-full w-8 h-8 flex items-center justify-center text-sm font-bold shadow-lg z-20 animate-pulse">
          ⏭{@pending_skips}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a visual deck with card backs, showing deck size and allowing click-to-draw.
  """
  attr :deck_size, :integer, required: true
  attr :can_draw, :boolean, default: false
  attr :player_id, :string, default: nil
  attr :layout, :string, default: "default"

  def deck_display(assigns) do
    ~H"""
    <div class={[
      "relative w-full h-full",
      @can_draw && @deck_size > 0 && "deck-can-draw"
    ]}>
      <!-- Deck stack effect - multiple card backs -->
      <%= if @deck_size > 0 do %>
        <%= for i <- 1..min(@deck_size, 4) do %>
          <div
            class={"absolute w-full h-full rounded-2xl theme-shadow-lg #{if i == 1, do: "z-10", else: "z-#{10-i}"}"}
            style={"background-color: var(--theme-bg-secondary); border: 2px solid var(--theme-card-border); top: #{(i-1) * 2}px; left: #{(i-1) * 2}px; transform: rotate(#{(i - 2) * 1}deg);"}
          >
            <!-- Card back pattern -->
            <div
              class="w-full h-full flex items-center justify-center rounded-2xl card-back relative overflow-hidden"
              style="background: var(--theme-card-back-gradient); background-size: var(--theme-card-back-pattern-size);"
            >
              <!-- Decorative center -->
              <div class="absolute inset-0 flex items-center justify-center">
                <div
                  class="w-16 h-16 rounded-full flex items-center justify-center"
                  style="background-color: var(--theme-card-decoration); border: 2px solid var(--theme-primary);"
                >
                  <div class="text-3xl font-bold" style="color: var(--theme-primary);">R</div>
                </div>
              </div>
              <!-- Corner decorations -->
              <div
                class="absolute top-2 left-2 text-xl opacity-40"
                style="color: var(--theme-text-inverse);"
              >
                ♠
              </div>
              <div
                class="absolute top-2 right-2 text-xl opacity-40"
                style="color: var(--theme-text-inverse);"
              >
                ♥
              </div>
              <div
                class="absolute bottom-2 left-2 text-xl opacity-40"
                style="color: var(--theme-text-inverse);"
              >
                ♦
              </div>
              <div
                class="absolute bottom-2 right-2 text-xl opacity-40"
                style="color: var(--theme-text-inverse);"
              >
                ♣
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <!-- Empty deck placeholder -->
        <div
          class="w-full h-full border-2 border-dashed rounded-2xl flex items-center justify-center"
          style="border-color: var(--theme-text-tertiary);"
        >
          <div class="text-sm font-bold theme-text-tertiary">Empty</div>
        </div>
      <% end %>
      
    <!-- Clickable overlay when can draw -->
      <%= if @can_draw && @deck_size > 0 do %>
        <button
          id={"deck-draw-button-#{@layout}-#{@player_id || "default"}"}
          phx-click="draw_card"
          phx-hook="ClickDebounce"
          data-debounce="500"
          class={
            [
              "absolute inset-0 z-20 rounded-2xl transition-all duration-300 cursor-pointer group touch-manipulation",
              # Enhanced mobile touch feedback
              "active:scale-95",
              # Better ring visibility on mobile
              "hover:ring-4 hover:ring-green-400 focus:ring-4 focus:ring-green-400"
            ]
          }
          title="Draw cards from deck"
          aria-label={"Draw cards from deck, #{@deck_size} cards remaining"}
        >
          <!-- Background overlay - more visible on mobile -->
          <div
            class="absolute inset-0 rounded-2xl transition-opacity duration-300 opacity-30 lg:opacity-0 group-hover:opacity-100 group-focus:opacity-100"
            style="background-color: var(--theme-success); opacity: 0.2;"
          >
          </div>
          
    <!-- Draw text/icon - always visible on mobile -->
          <div class={
            [
              "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-white font-bold transition-opacity flex flex-col items-center",
              # Always visible on mobile, hover on desktop
              "opacity-80 lg:opacity-0 group-hover:opacity-100 group-focus:opacity-100"
            ]
          }>
            <div class="text-2xl mb-1">⬇️</div>
            <div class="text-xs lg:text-sm">Draw</div>
          </div>
        </button>
      <% end %>
      
    <!-- Deck count indicator -->
      <%= if @deck_size > 0 do %>
        <div
          class="absolute -bottom-2 -right-2 rounded-full w-8 h-8 flex items-center justify-center text-sm font-bold shadow-lg z-30"
          style="background-color: var(--theme-primary); color: var(--theme-text-inverse);"
        >
          {@deck_size}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a player info card with animation.
  """
  attr :player, :map, required: true
  attr :is_current, :boolean, default: false
  attr :card_count, :integer, required: true

  def player_card(assigns) do
    ~H"""
    <div
      class={[
        "relative p-2 md:p-4 rounded-lg transition-all duration-300",
        @is_current &&
          "current-player bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg scale-105",
        !@is_current && "bg-gray-100 hover:bg-gray-200"
      ]}
      role="status"
      aria-label={player_status_label(@player, @is_current, @card_count)}
    >
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-2 md:gap-3">
          <div
            class={[
              "w-10 h-10 md:w-10 md:h-10 rounded-full flex items-center justify-center font-bold text-sm",
              @is_current && "bg-white text-blue-600",
              !@is_current && "bg-gray-300 text-gray-700"
            ]}
            aria-hidden="true"
          >
            {get_initials(@player.name)}
          </div>
          <div class="hidden md:flex items-center gap-2">
            <div class="font-semibold">{@player.name}</div>
            <%= if @player.is_ai do %>
              <div class="text-xs opacity-80" aria-label="Computer player">🖥️</div>
            <% end %>
          </div>
          <%= if @player.is_ai do %>
            <div class="text-xs opacity-80 md:hidden" aria-label="Computer player">🖥️</div>
          <% end %>
        </div>
        <div
          class={[
            "px-2 md:px-3 py-1 rounded-full text-sm font-bold",
            @is_current && "bg-white/20",
            !@is_current && "bg-gray-200"
          ]}
          aria-label={"#{@card_count} cards in hand"}
        >
          {format_card_count(@card_count)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a horizontal player info card for space-efficient layout.
  """
  attr :player, :map, required: true
  attr :is_current, :boolean, default: false
  attr :is_you, :boolean, default: false
  attr :card_count, :integer, required: true

  def player_card_horizontal(assigns) do
    ~H"""
    <div
      class={
        [
          "flex items-center gap-1 md:gap-2 px-1.5 md:px-3 py-1.5 md:py-2 rounded-lg transition-all duration-300 relative text-xs md:text-sm",
          # Current player styling (whose turn it is)
          @is_current && @is_you &&
            "bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-lg ring-2 ring-white/30",
          @is_current && !@is_you &&
            "bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg ring-2 ring-white/30",
          # You styling (when it's not your turn)
          !@is_current && @is_you &&
            "bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-md ring-1 ring-white/20",
          # Add disconnected styling
          Map.get(@player, :connected, true) == false && "opacity-60"
        ]
      }
      style={
        if !@is_current && !@is_you do
          "background-color: var(--theme-bg-secondary); color: var(--theme-text-primary);"
        else
          ""
        end
      }
    >
      <div
        class={[
          "w-6 h-6 md:w-8 md:h-8 rounded-full flex items-center justify-center font-bold text-xs md:text-sm flex-shrink-0",
          (@is_current || @is_you) && "bg-white/90 text-gray-800"
        ]}
        style={
          if !@is_current && !@is_you do
            "background-color: var(--theme-bg-primary); color: var(--theme-text-primary);"
          else
            ""
          end
        }
      >
        {get_initials(@player.name)}
      </div>
      <div class="flex items-center gap-1 min-w-0">
        <div
          class={[
            "font-semibold text-xs md:text-sm hidden sm:block truncate",
            (@is_current || @is_you) && "text-white"
          ]}
          style={
            if !@is_current && !@is_you do
              "color: var(--theme-text-primary);"
            else
              ""
            end
          }
        >
          {@player.name}
        </div>
        <%= if @player.is_ai do %>
          <div class="text-xs opacity-80 flex-shrink-0 hidden sm:block" title="AI Player">🖥️</div>
        <% end %>
        <%= if Map.get(@player, :connected, true) == false && !@player.is_ai do %>
          <div class="text-xs opacity-80 flex-shrink-0" title="Disconnected">🔴</div>
        <% end %>
      </div>
      <div
        class={[
          "px-1.5 md:px-2 py-0.5 md:py-1 rounded-full text-xs font-bold flex-shrink-0",
          (@is_current || @is_you) && "bg-white/20 text-white"
        ]}
        style={
          if !@is_current && !@is_you do
            "background-color: var(--theme-bg-tertiary); color: var(--theme-text-primary);"
          else
            ""
          end
        }
      >
        {format_card_count(@card_count)}
      </div>
    </div>
    """
  end

  @doc """
  Renders game status indicators with animations.
  """
  attr :game, :map, required: true

  def game_status(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <!-- Pending Pickups -->
      <%= if @game.pending_pickups > 0 do %>
        <div class="bg-red-500/20 backdrop-blur rounded-xl p-4 text-center animate-pulse">
          <div class="text-sm text-red-300 mb-1">Pending</div>
          <div class="text-2xl font-bold text-red-400">
            +{@game.pending_pickups} cards
          </div>
        </div>
      <% end %>
      
    <!-- Pending Skips -->
      <%= if @game.pending_skips > 0 do %>
        <div class="bg-yellow-500/20 backdrop-blur rounded-xl p-4 text-center animate-pulse">
          <div class="text-sm text-yellow-300 mb-1">Pending</div>
          <div class="text-2xl font-bold text-yellow-400">
            {pluralize_skips(@game.pending_skips)}
          </div>
        </div>
      <% end %>
      
    <!-- Nominated Suit -->
      <%= if Map.get(@game, :nominated_suit) && @game.nominated_suit != :pending do %>
        <div class="nominated-suit-indicator rounded-xl p-4 text-center">
          <div class="text-sm mb-1">Must Play</div>
          <div class="text-2xl font-bold">
            {format_suit(@game.nominated_suit)}
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders suit selection interface.
  """
  attr :id, :string, default: "suit-selector"

  def suit_selector(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/50 backdrop-blur flex items-center justify-center z-50"
      role="dialog"
      aria-labelledby="suit-selector-title"
      aria-describedby="suit-selector-description"
    >
      <div
        id="suit-selector-modal"
        class="rounded-2xl p-8 theme-shadow-2xl transform scale-100 animate-bounce-in max-w-md w-full mx-4"
        style="background-color: var(--theme-card-bg);"
        phx-hook="SuitSelector"
      >
        <h2 id="suit-selector-title" class="text-2xl font-bold text-center mb-6 theme-text-primary">
          Choose a Suit
        </h2>
        <p id="suit-selector-description" class="text-center mb-8 theme-text-secondary">
          Select the suit that the next player must play. Use arrow keys to navigate and Enter to select.
        </p>
        <div class="grid grid-cols-2 gap-4" role="radiogroup" aria-labelledby="suit-selector-title">
          <button
            id="suit-hearts-btn"
            phx-click="nominate_suit"
            phx-value-suit="hearts"
            phx-hook="ClickDebounce"
            data-debounce="500"
            class="p-6 rounded-xl transition-colors group touch-manipulation theme-text-primary"
            style="background-color: var(--theme-bg-secondary); border: 2px solid transparent;"
            onmouseover="this.style.borderColor='var(--theme-card-red)'"
            onmouseout="this.style.borderColor='transparent'"
            onfocus="this.style.borderColor='var(--theme-card-red)'"
            onblur="this.style.borderColor='transparent'"
            aria-label="Hearts suit"
            role="radio"
            tabindex="0"
            data-suit="hearts"
          >
            <div
              class="text-6xl group-hover:scale-110 group-focus:scale-110 transition-transform"
              style="color: var(--theme-card-red);"
            >
              ♥
            </div>
            <div class="mt-2 font-semibold">Hearts</div>
          </button>
          <button
            id="suit-diamonds-btn"
            phx-click="nominate_suit"
            phx-value-suit="diamonds"
            phx-hook="ClickDebounce"
            data-debounce="500"
            class="p-6 rounded-xl transition-colors group touch-manipulation theme-text-primary"
            style="background-color: var(--theme-bg-secondary); border: 2px solid transparent;"
            onmouseover="this.style.borderColor='var(--theme-card-red)'"
            onmouseout="this.style.borderColor='transparent'"
            onfocus="this.style.borderColor='var(--theme-card-red)'"
            onblur="this.style.borderColor='transparent'"
            aria-label="Diamonds suit"
            role="radio"
            tabindex="-1"
            data-suit="diamonds"
          >
            <div
              class="text-6xl group-hover:scale-110 group-focus:scale-110 transition-transform"
              style="color: var(--theme-card-red);"
            >
              ♦
            </div>
            <div class="mt-2 font-semibold">Diamonds</div>
          </button>
          <button
            id="suit-clubs-btn"
            phx-click="nominate_suit"
            phx-value-suit="clubs"
            phx-hook="ClickDebounce"
            data-debounce="500"
            class="p-6 rounded-xl transition-colors group touch-manipulation theme-text-primary"
            style="background-color: var(--theme-bg-secondary); border: 2px solid transparent;"
            onmouseover="this.style.borderColor='var(--theme-card-black)'"
            onmouseout="this.style.borderColor='transparent'"
            onfocus="this.style.borderColor='var(--theme-card-black)'"
            onblur="this.style.borderColor='transparent'"
            aria-label="Clubs suit"
            role="radio"
            tabindex="-1"
            data-suit="clubs"
          >
            <div
              class="text-6xl group-hover:scale-110 group-focus:scale-110 transition-transform"
              style="color: var(--theme-card-black);"
            >
              ♣
            </div>
            <div class="mt-2 font-semibold">Clubs</div>
          </button>
          <button
            id="suit-spades-btn"
            phx-click="nominate_suit"
            phx-value-suit="spades"
            phx-hook="ClickDebounce"
            data-debounce="500"
            class="p-6 rounded-xl transition-colors group touch-manipulation theme-text-primary"
            style="background-color: var(--theme-bg-secondary); border: 2px solid transparent;"
            onmouseover="this.style.borderColor='var(--theme-card-black)'"
            onmouseout="this.style.borderColor='transparent'"
            onfocus="this.style.borderColor='var(--theme-card-black)'"
            onblur="this.style.borderColor='transparent'"
            aria-label="Spades suit"
            role="radio"
            tabindex="-1"
            data-suit="spades"
          >
            <div
              class="text-6xl group-hover:scale-110 group-focus:scale-110 transition-transform"
              style="color: var(--theme-card-black);"
            >
              ♠
            </div>
            <div class="mt-2 font-semibold">Spades</div>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp card_red?(card) do
    card.suit in [:hearts, :diamonds]
  end

  defp card_display(card) do
    "#{rank_to_string(card.rank)}#{suit_to_symbol(card.suit)}"
  end

  defp rank_to_string(:ace), do: "A"
  defp rank_to_string(:king), do: "K"
  defp rank_to_string(:queen), do: "Q"
  defp rank_to_string(:jack), do: "J"
  defp rank_to_string(rank) when is_integer(rank), do: to_string(rank)

  defp suit_to_symbol(:hearts), do: "♥"
  defp suit_to_symbol(:diamonds), do: "♦"
  defp suit_to_symbol(:clubs), do: "♣"
  defp suit_to_symbol(:spades), do: "♠"

  defp format_suit(suit) do
    case suit do
      :hearts -> "♥ Hearts"
      :diamonds -> "♦ Diamonds"
      :clubs -> "♣ Clubs"
      :spades -> "♠ Spades"
    end
  end

  defp format_card_count(n), do: "#{n}"

  defp pluralize_skips(1), do: "1 skip"
  defp pluralize_skips(n), do: "#{n} skips"

  defp get_initials(name) do
    name
    |> String.trim()
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  @doc """
  Renders an AI thinking indicator with animated dots.
  """
  def ai_thinking_indicator(assigns) do
    ~H"""
    <div
      class="flex items-center gap-2 px-4 py-2 bg-white/10 backdrop-blur rounded-full"
      role="status"
      aria-label="AI is thinking"
    >
      <div class="text-white/80 text-sm font-medium">AI is thinking</div>
      <div class="flex gap-1">
        <div
          class="w-2 h-2 bg-white/60 rounded-full animate-bounce"
          style="animation-delay: 0ms"
          aria-hidden="true"
        >
        </div>
        <div
          class="w-2 h-2 bg-white/60 rounded-full animate-bounce"
          style="animation-delay: 150ms"
          aria-hidden="true"
        >
        </div>
        <div
          class="w-2 h-2 bg-white/60 rounded-full animate-bounce"
          style="animation-delay: 300ms"
          aria-hidden="true"
        >
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading spinner for game actions.
  """
  attr :text, :string, default: "Loading..."
  attr :size, :string, default: "medium", values: ["small", "medium", "large"]

  def loading_spinner(assigns) do
    ~H"""
    <div
      class={[
        "flex items-center gap-3",
        @size == "small" && "text-sm",
        @size == "medium" && "text-base",
        @size == "large" && "text-lg"
      ]}
      role="status"
      aria-label={@text}
    >
      <div
        class={[
          "animate-spin rounded-full border-2 border-transparent border-t-current",
          @size == "small" && "w-4 h-4",
          @size == "medium" && "w-5 h-5",
          @size == "large" && "w-6 h-6"
        ]}
        aria-hidden="true"
      >
      </div>
      <span class="font-medium">{@text}</span>
    </div>
    """
  end

  @doc """
  Renders action buttons with loading states.
  """
  attr :loading, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :variant, :string, default: "primary", values: ["primary", "secondary", "danger"]
  attr :text, :string, required: true
  attr :loading_text, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value-suit)

  def action_button(assigns) do
    assigns = assign(assigns, :loading_text, assigns[:loading_text] || "#{assigns.text}...")

    ~H"""
    <button
      class={[
        "relative px-6 py-3 rounded-xl font-semibold transition-all duration-300 min-h-[48px] touch-manipulation",
        "focus:ring-4 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed",
        @variant == "primary" && "bg-blue-500 hover:bg-blue-600 focus:ring-blue-300 text-white",
        @variant == "secondary" && "bg-gray-500 hover:bg-gray-600 focus:ring-gray-300 text-white",
        @variant == "danger" && "bg-red-500 hover:bg-red-600 focus:ring-red-300 text-white",
        (@loading || @disabled) && "pointer-events-none"
      ]}
      disabled={@loading || @disabled}
      aria-label={if @loading, do: @loading_text, else: @text}
      {@rest}
    >
      <!-- Normal content -->
      <span class={["transition-opacity duration-200", @loading && "opacity-0"]}>
        {@text}
      </span>
      
    <!-- Loading content -->
      <%= if @loading do %>
        <div class="absolute inset-0 flex items-center justify-center">
          <.loading_spinner text={@loading_text} size="small" />
        </div>
      <% end %>
    </button>
    """
  end

  # Additional helper functions for special cards
  defp special_card?(card) do
    card.rank in [:ace, :queen, :jack, 7, 2]
  end

  defp pickup_card?(card) do
    card.rank == 2 || (card.rank == :jack && card.suit in [:clubs, :spades])
  end

  defp card_effect_text(card) do
    cond do
      card.rank == 2 -> "+2"
      card.rank == :jack && card.suit in [:clubs, :spades] -> "+5"
      card.rank == 7 -> "⏭"
      card.rank == :queen -> "↻"
      card.rank == :ace -> "♠"
      true -> ""
    end
  end

  defp special_icon(card) do
    cond do
      card.rank == 2 -> "⚡"
      card.rank == :jack && card.suit in [:clubs, :spades] -> "💀"
      card.rank == 7 -> "⏩"
      card.rank == :queen -> "🔄"
      card.rank == :ace -> "🌟"
      true -> ""
    end
  end

  defp card_aria_label(card, selected) do
    base_label = "#{rank_to_string(card.rank)} of #{String.capitalize(Atom.to_string(card.suit))}"

    effect_text =
      case card_effect_text(card) do
        "" -> ""
        effect -> ", special effect: #{effect}"
      end

    selected_text = if selected, do: ", selected", else: ""
    base_label <> effect_text <> selected_text
  end

  defp player_status_label(player, is_current, card_count) do
    base = "#{player.name}, #{card_count} cards"
    ai_text = if player.is_ai, do: ", computer player", else: ""
    current_text = if is_current, do: ", current turn", else: ""
    base <> ai_text <> current_text
  end
end
