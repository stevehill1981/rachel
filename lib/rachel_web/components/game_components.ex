defmodule RachelWeb.GameComponents do
  @moduledoc """
  Game-specific UI components for Rachel card game.
  """
  use Phoenix.Component

  alias Rachel.Games.{Card, Game}

  @doc """
  Renders a playing card with animations and proper styling.
  """
  attr :card, Card, required: true
  attr :selected, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :index, :integer, default: nil
  attr :rest, :global

  def playing_card(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "playing-card relative px-6 py-8 text-4xl font-bold rounded-lg",
        "bg-white border-2 border-gray-300 shadow-lg",
        "transition-all duration-300 transform hover:scale-105",
        @selected && "selected ring-4 ring-blue-500 -translate-y-4",
        @disabled && "opacity-50 cursor-not-allowed",
        !@disabled && "hover:shadow-xl cursor-pointer"
      ]}
      disabled={@disabled}
      {@rest}
    >
      <span class={[
        Card.red?(@card) && "card-suit-red",
        !Card.red?(@card) && "card-suit-black"
      ]}>
        {card_display(@card)}
      </span>
      <%= if @selected do %>
        <span class="absolute -top-2 -right-2 w-6 h-6 bg-blue-500 text-white rounded-full text-sm flex items-center justify-center">
          ✓
        </span>
      <% end %>
    </button>
    """
  end

  @doc """
  Renders the current card in play with special effects.
  """
  attr :card, Card, default: nil

  def current_card_display(assigns) do
    ~H"""
    <div class="relative">
      <div class="absolute inset-0 bg-gradient-to-r from-purple-400 to-pink-400 rounded-2xl blur-xl opacity-30 animate-pulse">
      </div>
      <div class="relative bg-white rounded-2xl p-8 shadow-2xl transform hover:rotate-3 transition-transform">
        <%= if @card do %>
          <div class={[
            "text-8xl font-bold text-center",
            Card.red?(@card) && "card-suit-red",
            !Card.red?(@card) && "card-suit-black"
          ]}>
            {card_display(@card)}
          </div>
          <div class="text-center mt-4 text-gray-600">
            <%= if special = Card.special_effect(@card) do %>
              <span class="text-sm font-semibold px-3 py-1 bg-purple-100 text-purple-800 rounded-full">
                {special_effect_text(special)}
              </span>
            <% end %>
          </div>
        <% else %>
          <div class="text-6xl text-gray-300 text-center">
            <div class="card-back w-32 h-44 mx-auto rounded-lg"></div>
          </div>
        <% end %>
      </div>
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
    <div class={[
      "relative p-4 rounded-lg transition-all duration-300",
      @is_current &&
        "current-player bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg scale-105",
      !@is_current && "bg-gray-100 hover:bg-gray-200"
    ]}>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class={[
            "w-10 h-10 rounded-full flex items-center justify-center font-bold",
            @is_current && "bg-white text-blue-600",
            !@is_current && "bg-gray-300 text-gray-700"
          ]}>
            {String.first(@player.name)}
          </div>
          <div>
            <div class="font-semibold">{@player.name}</div>
            <%= if @player.is_ai do %>
              <div class="text-xs opacity-80">AI Player</div>
            <% end %>
          </div>
        </div>
        <div class={[
          "px-3 py-1 rounded-full text-sm font-bold",
          @is_current && "bg-white/20",
          !@is_current && "bg-gray-200"
        ]}>
          {format_card_count(@card_count)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders game status indicators with animations.
  """
  attr :game, Game, required: true

  def game_status(assigns) do
    ~H"""
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Direction Indicator -->
      <div class="bg-white/10 backdrop-blur rounded-xl p-4 text-center">
        <div class="text-sm text-gray-300 mb-1">Direction</div>
        <div class="text-2xl font-bold text-white flex items-center justify-center gap-2">
          <%= if @game.direction == :clockwise do %>
            <span class="animate-spin">↻</span> Clockwise
          <% else %>
            <span class="animate-spin">↺</span> Counter
          <% end %>
        </div>
      </div>
      
    <!-- Deck Size -->
      <div class="bg-white/10 backdrop-blur rounded-xl p-4 text-center">
        <div class="text-sm text-gray-300 mb-1">Deck</div>
        <div class="text-2xl font-bold text-white">
          {Rachel.Games.Deck.size(@game.deck)} cards
        </div>
      </div>
      
    <!-- Pending Pickups -->
      <%= if @game.pending_pickups > 0 do %>
        <div class="bg-red-500/20 backdrop-blur rounded-xl p-4 text-center animate-pulse">
          <div class="text-sm text-red-300 mb-1">Pending</div>
          <div class="text-2xl font-bold text-red-400">
            +{@game.pending_pickups} cards
          </div>
        </div>
      <% end %>
      
    <!-- Nominated Suit -->
      <%= if @game.nominated_suit && @game.nominated_suit != :pending do %>
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
    <div class="fixed inset-0 bg-black/50 backdrop-blur flex items-center justify-center z-50">
      <div class="bg-white rounded-2xl p-8 shadow-2xl transform scale-100 animate-bounce-in max-w-md w-full mx-4">
        <h2 class="text-2xl font-bold text-center mb-6">Choose a Suit</h2>
        <p class="text-gray-600 text-center mb-8">
          Select the suit that the next player must play
        </p>
        <div class="grid grid-cols-2 gap-4">
          <button
            phx-click="nominate_suit"
            phx-value-suit="hearts"
            class="p-6 rounded-xl bg-red-50 hover:bg-red-100 transition-colors group"
          >
            <div class="text-6xl text-red-500 group-hover:scale-110 transition-transform">♥</div>
            <div class="mt-2 font-semibold">Hearts</div>
          </button>
          <button
            phx-click="nominate_suit"
            phx-value-suit="diamonds"
            class="p-6 rounded-xl bg-red-50 hover:bg-red-100 transition-colors group"
          >
            <div class="text-6xl text-red-500 group-hover:scale-110 transition-transform">♦</div>
            <div class="mt-2 font-semibold">Diamonds</div>
          </button>
          <button
            phx-click="nominate_suit"
            phx-value-suit="clubs"
            class="p-6 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors group"
          >
            <div class="text-6xl text-black group-hover:scale-110 transition-transform">♣</div>
            <div class="mt-2 font-semibold">Clubs</div>
          </button>
          <button
            phx-click="nominate_suit"
            phx-value-suit="spades"
            class="p-6 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors group"
          >
            <div class="text-6xl text-black group-hover:scale-110 transition-transform">♠</div>
            <div class="mt-2 font-semibold">Spades</div>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp card_display(card) do
    rank =
      case card.rank do
        :ace -> "A"
        :king -> "K"
        :queen -> "Q"
        :jack -> "J"
        rank when is_integer(rank) -> to_string(rank)
      end

    suit =
      case card.suit do
        :hearts -> "♥"
        :diamonds -> "♦"
        :clubs -> "♣"
        :spades -> "♠"
      end

    "#{rank}#{suit}"
  end

  defp format_suit(suit) do
    case suit do
      :hearts -> "♥ Hearts"
      :diamonds -> "♦ Diamonds"
      :clubs -> "♣ Clubs"
      :spades -> "♠ Spades"
    end
  end

  defp format_card_count(1), do: "1 card"
  defp format_card_count(n), do: "#{n} cards"

  defp special_effect_text(effect) do
    case effect do
      :pick_two -> "Next player draws 2"
      :reverse -> "Reverses direction"
      :skip -> "Skips next player"
      :nominate -> "Choose next suit"
      :pick_five -> "Next player draws 5"
      _ -> ""
    end
  end
end
