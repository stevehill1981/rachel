defmodule RachelWeb.Components.Game.PlayersDisplay do
  @moduledoc """
  Players display component for active games
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  import RachelWeb.Components.Game.DirectionIndicator
  
  attr :game, :map, required: true
  
  def players_display(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur rounded-2xl p-6 mb-8">
      <div class="flex flex-wrap gap-4 justify-center items-center">
        <.direction_indicator direction={@game.direction} />
        
        <%= for {player, idx} <- Enum.with_index(@game.players) do %>
          <.player_card_horizontal
            player={player}
            is_current={idx == @game.current_player_index}
            card_count={length(player.hand)}
          />
        <% end %>
        
        <.direction_indicator direction={@game.direction} />
      </div>
    </div>
    """
  end
end