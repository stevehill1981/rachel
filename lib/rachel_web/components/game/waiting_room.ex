defmodule RachelWeb.Components.Game.WaitingRoom do
  @moduledoc """
  Waiting room component for multiplayer games
  """
  use Phoenix.Component

  attr :game, :map, required: true
  attr :game_id, :string, required: true
  attr :player_id, :string, required: true

  def waiting_room(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur rounded-2xl p-8 max-w-3xl mx-auto">
      <h2 class="text-3xl font-bold text-white text-center mb-8">Waiting for Players</h2>
      
    <!-- Game Info -->
      <div class="text-center mb-8">
        <p class="text-white/80 mb-2">Share this game code with friends:</p>
        <div class="inline-flex items-center gap-3 bg-white/20 rounded-lg px-6 py-3">
          <span class="text-3xl font-mono font-bold text-white">
            {if @game_id, do: String.slice(@game_id, -6..-1), else: "------"}
          </span>
          <button
            phx-click="copy_game_code"
            class="text-white/60 hover:text-white transition-colors text-2xl"
            title="Copy game code"
          >
            📋
          </button>
        </div>
      </div>
      
    <!-- Players List -->
      <div class="mb-8">
        <h3 class="text-xl font-semibold text-white mb-4">
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
    """
  end

  attr :player, :map, required: true
  attr :player_id, :string, required: true
  attr :host_id, :string, required: true

  defp player_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between bg-white/10 rounded-lg px-4 py-3">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-white font-bold">
          {String.first(@player.name)}
        </div>
        <div>
          <div class="text-white font-semibold">
            {@player.name}
            <%= if @player.id == @player_id do %>
              <span class="text-white/60 text-sm ml-2">(You)</span>
            <% end %>
            <%= if @player.id == @host_id do %>
              <span class="text-yellow-400 text-sm ml-2">👑 Host</span>
            <% end %>
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <%= if Map.get(@player, :connected, true) do %>
          <span class="text-green-400">●</span>
        <% else %>
          <span class="text-red-400">●</span>
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
            class="px-8 py-3 bg-green-600 text-white text-lg font-semibold rounded-lg hover:bg-green-700 transition-colors shadow-lg"
          >
            Start Game
          </button>
          <p class="text-white/60 text-sm mt-2">Minimum 2 players required</p>
        <% else %>
          <button
            disabled
            class="px-8 py-3 bg-gray-600 text-gray-400 text-lg font-semibold rounded-lg cursor-not-allowed shadow-lg"
          >
            Waiting for more players...
          </button>
          <p class="text-white/60 text-sm mt-2">Need at least 2 players to start</p>
        <% end %>
      <% else %>
        <p class="text-white/80">Waiting for the host to start the game...</p>
      <% end %>
    </div>
    """
  end
end
