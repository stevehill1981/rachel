defmodule RachelWeb.Components.Game.GameHeader do
  @moduledoc """
  Game header component with navigation and game code display
  """
  use Phoenix.Component
  
  attr :game_id, :string, default: nil
  
  def game_header(assigns) do
    ~H"""
    <header class="relative z-10 p-4">
      <div class="max-w-7xl mx-auto">
        <div class="flex items-center justify-between">
          <div class="flex-1">
            <%= if @game_id do %>
              <a href="/lobby" class="text-white/80 hover:text-white transition-colors">
                ← Back to Lobby
              </a>
            <% end %>
          </div>
          
          <h1 class="text-3xl font-bold text-white tracking-wide text-center flex-1">
            Rachel
          </h1>
          
          <div class="flex-1 text-right">
            <%= if @game_id do %>
              <div class="inline-flex items-center gap-2 bg-white/10 backdrop-blur rounded-lg px-4 py-2">
                <span class="text-white/60 text-sm">Game Code:</span>
                <span class="text-white font-mono font-bold">{String.slice(@game_id, -6..-1)}</span>
                <button 
                  phx-click="copy_game_code" 
                  class="text-white/60 hover:text-white transition-colors"
                  title="Copy game code"
                >
                  📋
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </header>
    """
  end
end