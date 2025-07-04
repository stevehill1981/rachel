defmodule RachelWeb.Components.Game.GameInProgress do
  @moduledoc """
  Main game in progress view component
  """
  use Phoenix.Component
  import RachelWeb.Components.Game.{PlayersDisplay, DeckArea, PlayerHand}
  import RachelWeb.GameComponents

  # Import the current_player function from GameLive
  import RachelWeb.GameLive, only: [current_player: 1]

  attr :game, :map, required: true
  attr :player_id, :string, required: true
  attr :selected_cards, :list, default: []
  attr :show_ai_thinking, :boolean, default: false
  attr :is_spectator, :boolean, default: false

  def game_in_progress(assigns) do
    assigns = assign(assigns, :current_player, current_player(assigns.game))

    ~H"""
    <div>
      <.players_display game={@game} />
      <.deck_area
        game={@game}
        player_id={@player_id}
        show_ai_thinking={@show_ai_thinking}
        current_player={@current_player}
      />
      <.player_hand
        game={@game}
        player_id={@player_id}
        selected_cards={@selected_cards}
        current_player={@current_player}
        is_spectator={@is_spectator}
      />
      
    <!-- Suit Nomination -->
      <%= if !@is_spectator && Map.get(@game, :nominated_suit) == :pending && @current_player && @current_player.id == @player_id do %>
        <.suit_selector />
      <% end %>
    </div>
    """
  end
end
