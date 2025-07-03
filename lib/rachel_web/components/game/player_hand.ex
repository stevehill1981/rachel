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
  
  def player_hand(assigns) do
    assigns = assign(assigns, :player, find_player(assigns.game, assigns.player_id))
    
    ~H"""
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
                !RachelWeb.GameLive.can_select_card?(@game, card, @selected_cards, @player.hand)
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