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

  def player_hand(assigns) do
    assigns = assign(assigns, :player, find_player(assigns.game, assigns.player_id))

    ~H"""
    <%= if @is_spectator do %>
      <div class="bg-white/10 backdrop-blur rounded-2xl p-6">
        <div class="text-center mb-4">
          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
            Spectating
          </span>
        </div>
        <.spectator_view game={@game} current_player={@current_player} />
      </div>
    <% else %>
      <%= if @player_id not in @game.winners do %>
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
      <div class="flex justify-center mb-4">
        <button
          phx-click="play_cards"
          class="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors font-semibold"
        >
          Play {length(@selected_cards)} Card{if length(@selected_cards) == 1, do: "", else: "s"}
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
      <div class="mb-4 p-3 bg-red-500/20 rounded-lg border border-red-400/30 animate-pulse game-message">
        <div class="text-center text-red-200 font-semibold">
          Drawing {@game.pending_pickups} cards...
        </div>
      </div>
    <% end %>

    <%= if @current_player && @current_player.id != @player_id && @game.status == :playing do %>
      <div class="mb-4 p-3 bg-gray-500/20 rounded-lg border border-gray-400/30 game-message">
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
    ~H"""
    <%= if @player do %>
      <div class="grid grid-cols-4 lg:grid-cols-8 gap-2">
        <%= for {card, idx} <- Enum.with_index(@player.hand) do %>
          <div class="flex justify-center">
            <.playing_card
              card={card}
              index={idx}
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
