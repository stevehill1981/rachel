defmodule RachelWeb.Components.Game.PlayersDisplay do
  @moduledoc """
  Players display component for active games
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  import RachelWeb.Components.Game.DirectionIndicator

  attr :game, :map, required: true
  attr :player_id, :string, required: true

  def players_display(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur rounded-2xl p-2 md:p-4 mb-3 md:mb-6">
      <div class="flex flex-wrap gap-1 md:gap-2 justify-center items-center max-w-full overflow-hidden">
        <.direction_indicator direction={Map.get(@game, :direction, :clockwise)} />

        <%= for {player, idx} <- Enum.with_index(@game.players) do %>
          <.player_card_horizontal
            player={player}
            is_current={idx == @game.current_player_index}
            is_you={player.id == @player_id}
            card_count={length(player.hand)}
          />
        <% end %>

        <.direction_indicator direction={Map.get(@game, :direction, :clockwise)} />
      </div>
    </div>
    """
  end
end
