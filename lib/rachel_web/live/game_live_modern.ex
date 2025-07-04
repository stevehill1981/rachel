defmodule RachelWeb.GameLive.Modern do
  @moduledoc """
  Modern UI template for the game
  """

  use Phoenix.Component
  import RachelWeb.Components.Game.{GameHeader, WaitingRoom, GameInProgress}

  def render(assigns) do
    ~H"""
    <div class="game-board min-h-screen">
      <.game_header game_id={@game_id} />
      
    <!-- Flash Messages -->
      <.flash_messages flash={@flash} />
      
    <!-- Main Game Area -->
      <main class="relative z-10 p-4 max-w-7xl mx-auto">
        <%= cond do %>
          <% !@game -> %>
            <div class="text-center text-white">Loading game...</div>
          <% @game.status == :waiting -> %>
            <.waiting_room game={@game} game_id={@game_id} player_id={@player_id} />
          <% true -> %>
            <.game_in_progress
              game={@game}
              player_id={@player_id}
              selected_cards={@selected_cards}
              show_ai_thinking={@show_ai_thinking}
              is_spectator={Map.get(assigns, :is_spectator, false)}
            />
        <% end %>
      </main>
      
    <!-- Confetti for winners -->
      <%= if @show_winner_banner do %>
        <div id="confetti-container" class="winner-celebration" phx-hook="WinnerCelebration"></div>
      <% end %>
    </div>
    """
  end

  attr :flash, :map, required: true

  defp flash_messages(assigns) do
    ~H"""
    <%= if Phoenix.Flash.get(@flash, :info) do %>
      <div
        id="flash-info"
        class="notification-enter fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 bg-green-500 text-white rounded-lg shadow-lg"
        phx-click="lv:clear-flash"
        phx-value-key="info"
        phx-hook="AutoHideFlash"
      >
        {Phoenix.Flash.get(@flash, :info)}
      </div>
    <% end %>

    <%= if Phoenix.Flash.get(@flash, :error) do %>
      <div
        id="flash-error"
        class="notification-enter fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 bg-red-500 text-white rounded-lg shadow-lg"
        phx-click="lv:clear-flash"
        phx-value-key="error"
        phx-hook="AutoHideFlash"
      >
        {Phoenix.Flash.get(@flash, :error)}
      </div>
    <% end %>
    """
  end
end
