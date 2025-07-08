defmodule RachelWeb.Components.Game.PlayersDisplay do
  @moduledoc """
  Players display component for active games
  """
  use Phoenix.Component

  attr :game, :map, required: true
  attr :player_id, :string, required: true

  def players_display(assigns) do
    ~H"""
    <div class="p-2 md:p-3 mb-3 md:mb-4">
      <div class="flex flex-col items-center gap-2">
        <!-- Player indicators with direction arrows between them -->
        <div class="flex items-center justify-center flex-wrap gap-1">
          <%= for {{player, idx}, i} <- Enum.with_index(Enum.with_index(@game.players)) do %>
            <%= if i > 0 do %>
              <!-- Direction arrow between players -->
              <div class="theme-text-secondary text-sm md:text-base mx-1">
                <%= if Map.get(@game, :direction, :clockwise) == :clockwise do %>
                  →
                <% else %>
                  ←
                <% end %>
              </div>
            <% end %>
            
            <.compact_player_indicator
              player={player}
              is_current={idx == @game.current_player_index}
              is_you={player.id == @player_id}
              card_count={length(player.hand)}
              game_players_count={length(@game.players)}
            />
          <% end %>
          
          <!-- Arrow wrapping back to first player -->
          <div class="theme-text-secondary text-sm md:text-base mx-1">
            <%= if Map.get(@game, :direction, :clockwise) == :clockwise do %>
              →
            <% else %>
              ←
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  attr :player, :map, required: true
  attr :is_current, :boolean, default: false
  attr :is_you, :boolean, default: false
  attr :card_count, :integer, required: true
  attr :game_players_count, :integer, required: true
  
  defp compact_player_indicator(assigns) do
    ~H"""
    <div
      class={[
        "relative transition-all duration-300",
        @is_current && "scale-125 z-10"
      ]}
      title={"#{@player.name} - #{@card_count} cards"}
    >
      <!-- AI indicator -->
      <%= if Map.get(@player, :is_ai, false) === true do %>
        <div class="absolute -top-1 -left-1 text-xs z-20">
          🤖
        </div>
      <% end %>
      
      <div
        class={[
          "w-8 h-8 md:w-10 md:h-10 rounded-full flex items-center justify-center font-bold text-xs md:text-sm",
          # Current player gets highlighted border
          @is_current && "ring-4 ring-white/50 shadow-lg",
          # Your indicator styling
          @is_you && @is_current && "bg-amber-500 text-white",
          @is_you && !@is_current && "bg-emerald-500 text-white",
          # Other players styling
          !@is_you && @is_current && "bg-blue-500 text-white",
          !@is_you && !@is_current && "theme-bg-secondary theme-text-tertiary",
          # Disconnected styling
          Map.get(@player, :connected, true) == false && "opacity-50"
        ]}
      >
        <%= if @game_players_count <= 6 do %>
          {get_initials(@player.name)}
        <% else %>
          {String.first(@player.name)}
        <% end %>
      </div>
      <!-- Card count badge -->
      <div
        class={[
          "absolute -bottom-1 -right-1 w-4 h-4 md:w-5 md:h-5 rounded-full flex items-center justify-center text-xs font-bold",
          @is_current && "bg-white text-gray-900",
          !@is_current && "theme-bg-tertiary theme-text-secondary"
        ]}
      >
        {format_compact_count(@card_count)}
      </div>
    </div>
    """
  end
  
  defp format_compact_count(count) when count > 9, do: "9+"
  defp format_compact_count(count), do: to_string(count)
  
  defp get_initials(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end
end
