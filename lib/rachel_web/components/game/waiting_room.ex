defmodule RachelWeb.Components.Game.WaitingRoom do
  @moduledoc """
  Waiting room component for multiplayer games
  """
  use Phoenix.Component
  import RachelWeb.ThemeComponents

  attr :game, :map, required: true
  attr :game_id, :string, required: true
  attr :player_id, :string, required: true

  def waiting_room(assigns) do
    ~H"""
    <div class="relative">
      <!-- Theme Selector - Top Right -->
      <div class="absolute top-4 right-4 z-40">
        <.theme_selector_button />
      </div>

      <div
        class="backdrop-blur rounded-2xl p-8 max-w-3xl mx-auto"
        style="background-color: var(--theme-bg-glass);"
      >
        <h2 class="text-3xl font-bold text-center mb-8 theme-text-primary">Waiting for Players</h2>
        
    <!-- Game Info -->
        <div class="text-center mb-8">
          <p class="theme-text-secondary mb-2">Share this game code with friends:</p>
          <div
            class="inline-flex items-center gap-3 rounded-lg px-6 py-3"
            style="background-color: var(--theme-bg-secondary);"
          >
            <span class="text-3xl font-mono font-bold theme-text-primary">
              {if @game_id, do: String.slice(@game_id, -6..-1), else: "------"}
            </span>
            <button
              phx-click="copy_game_code"
              class="theme-text-tertiary hover:theme-text-primary transition-colors text-2xl"
              title="Copy game code"
            >
              📋
            </button>
          </div>
        </div>
        
    <!-- Players List -->
        <div class="mb-8">
          <h3 class="text-xl font-semibold theme-text-primary mb-4">
            Players ({length(@game.players)}/8)
          </h3>
          <div class="space-y-3">
            <%= for player <- @game.players do %>
              <.player_item player={player} player_id={@player_id} host_id={Map.get(@game, :host_id)} />
            <% end %>
          </div>
        </div>
        
    <!-- Start Game Button -->
        <.start_game_section
          player_id={@player_id}
          host_id={Map.get(@game, :host_id)}
          player_count={length(@game.players)}
        />
      </div>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :player_id, :string, required: true
  attr :host_id, :string, required: true

  defp player_item(assigns) do
    ~H"""
    <div
      class="flex items-center justify-between rounded-lg px-4 py-3"
      style="background-color: var(--theme-bg-secondary);"
    >
      <div class="flex items-center gap-3">
        <div
          class="w-10 h-10 rounded-full flex items-center justify-center font-bold"
          style="background-color: var(--theme-primary); color: var(--theme-text-inverse);"
        >
          {String.first(@player.name)}
        </div>
        <div>
          <div class="theme-text-primary font-semibold">
            {@player.name}
            <%= if @player.id == @player_id do %>
              <span class="theme-text-secondary text-sm ml-2">(You)</span>
            <% end %>
            <%= if @player.id == @host_id do %>
              <span class="text-sm ml-2" style="color: var(--theme-success);">👑 Host</span>
            <% end %>
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <%= if Map.get(@player, :connected, true) do %>
          <span style="color: var(--theme-success);">●</span>
        <% else %>
          <span style="color: var(--theme-error);">●</span>
        <% end %>
      </div>
    </div>
    """
  end

  attr :player_id, :string, required: true
  attr :host_id, :string, required: true
  attr :player_count, :integer, required: true

  defp start_game_section(assigns) do
    ~H"""
    <div class="text-center">
      <%= if @player_id == @host_id do %>
        <%= if @player_count >= 2 do %>
          <button
            phx-click="start_game"
            class="px-8 py-3 text-lg font-semibold rounded-lg transition-colors shadow-lg"
            style="background-color: var(--theme-button-success); color: var(--theme-text-inverse);"
            onmouseover="this.style.filter='brightness(1.1)'"
            onmouseout="this.style.filter='brightness(1)'"
          >
            Start Game
          </button>
          <p class="theme-text-secondary text-sm mt-2">Minimum 2 players required</p>
        <% else %>
          <button
            disabled
            class="px-8 py-3 text-lg font-semibold rounded-lg cursor-not-allowed shadow-lg"
            style="background-color: var(--theme-bg-tertiary); color: var(--theme-text-tertiary);"
          >
            Waiting for more players...
          </button>
          <p class="theme-text-secondary text-sm mt-2">Need at least 2 players to start</p>
        <% end %>
      <% else %>
        <p class="theme-text-secondary">Waiting for the host to start the game...</p>
      <% end %>
    </div>
    """
  end
end
