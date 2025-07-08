defmodule RachelWeb.Components.Game.DirectionIndicator do
  @moduledoc """
  Direction indicator component for showing game play direction
  """
  use Phoenix.Component

  attr :direction, :atom, required: true

  def direction_indicator(assigns) do
    ~H"""
    <div class="text-white/60 text-sm md:text-xl direction-indicator hidden sm:block">
      <%= if @direction == :clockwise do %>
        →
      <% else %>
        ←
      <% end %>
    </div>
    """
  end
end
