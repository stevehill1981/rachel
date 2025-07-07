defmodule RachelWeb.AdminDashboardLive do
  @moduledoc """
  Admin monitoring dashboard for Rachel game.
  Shows real-time stats and system health.
  """
  
  use RachelWeb, :live_view
  alias Rachel.Games.GameServer
  
  @refresh_interval 5_000 # Refresh every 5 seconds
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Schedule periodic updates
      :timer.send_interval(@refresh_interval, self(), :refresh_stats)
    end
    
    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign_stats()
    
    {:ok, socket}
  end
  
  @impl true
  def handle_info(:refresh_stats, socket) do
    {:noreply, assign_stats(socket)}
  end
  
  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign_stats(socket)}
  end
  
  @impl true
  def handle_event("stop_game", %{"game_id" => game_id}, socket) do
    case GameServer.stop(game_id) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Game #{game_id} stopped")
          |> assign_stats()
        {:noreply, socket}
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to stop game")}
    end
  end
  
  defp assign_stats(socket) do
    # Get all active games
    active_games = get_active_games()
    
    # Get system stats
    memory_mb = :erlang.memory(:total) / 1_048_576
    
    # Get database stats
    db_stats = get_database_stats()
    
    # Get rate limiter stats
    rate_limit_stats = get_rate_limit_stats()
    
    # Get process counts
    process_count = :erlang.system_info(:process_count)
    
    socket
    |> assign(:active_games, active_games)
    |> assign(:total_games, length(active_games))
    |> assign(:total_players, count_total_players(active_games))
    |> assign(:memory_mb, Float.round(memory_mb, 2))
    |> assign(:memory_percentage, Float.round(memory_mb / 1024 * 100, 1))
    |> assign(:db_stats, db_stats)
    |> assign(:rate_limit_stats, rate_limit_stats)
    |> assign(:process_count, process_count)
    |> assign(:node_name, node() |> to_string())
    |> assign(:uptime, get_uptime())
    |> assign(:app_version, Application.spec(:rachel, :vsn) |> to_string())
  end
  
  defp get_active_games do
    Registry.select(Rachel.GameRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {game_id, pid, _} ->
      try do
        game = GameServer.get_state(game_id)
        %{
          id: game_id,
          pid: inspect(pid),
          status: game.status,
          player_count: length(game.players),
          players: Enum.map(game.players, & &1.name),
          current_player: get_current_player_name(game),
          created_at: game.id |> String.split("_") |> List.last() |> format_timestamp()
        }
      rescue
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.sort_by(& &1.created_at, :desc)
  end
  
  defp count_total_players(games) do
    games
    |> Enum.map(& &1.player_count)
    |> Enum.sum()
  end
  
  defp get_current_player_name(game) do
    if game.status == :playing and game.current_player_index do
      player = Enum.at(game.players, game.current_player_index)
      player && player.name
    end
  end
  
  defp get_database_stats do
    case Rachel.Repo.query("SELECT COUNT(*) as total FROM games_stats") do
      {:ok, %{rows: [[total]]}} ->
        %{total_games_recorded: total}
      _ ->
        %{total_games_recorded: 0}
    end
  end
  
  defp get_rate_limit_stats do
    # Get approximate count of rate limited IPs
    # This is a simple estimate based on ETS table size
    try do
      info = :ets.info(:rate_limiter)
      %{
        tracked_keys: Keyword.get(info, :size, 0),
        memory_bytes: Keyword.get(info, :memory, 0)
      }
    rescue
      _ -> %{tracked_keys: 0, memory_bytes: 0}
    end
  end
  
  defp get_uptime do
    {uptime, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(uptime, 1000)
    
    days = div(uptime_seconds, 86_400)
    hours = div(rem(uptime_seconds, 86_400), 3_600)
    minutes = div(rem(uptime_seconds, 3_600), 60)
    
    "#{days}d #{hours}h #{minutes}m"
  end
  
  defp format_timestamp(timestamp_str) do
    case Integer.parse(timestamp_str) do
      {ts, _} ->
        ts
        |> DateTime.from_unix!(:millisecond)
        |> Calendar.strftime("%H:%M:%S")
      _ ->
        timestamp_str
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-dashboard min-h-screen bg-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <div class="flex justify-between items-center">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
              <p class="text-gray-600 mt-1">Rachel Game Monitoring</p>
            </div>
            <div class="text-right text-sm text-gray-500">
              <p>Version: <%= @app_version %></p>
              <p>Node: <%= @node_name %></p>
              <p>Uptime: <%= @uptime %></p>
            </div>
          </div>
        </div>
        
        <!-- Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
          <!-- Active Games -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="p-3 bg-blue-100 rounded-full">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Active Games</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @total_games %></p>
              </div>
            </div>
          </div>
          
          <!-- Connected Players -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="p-3 bg-green-100 rounded-full">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Total Players</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @total_players %></p>
              </div>
            </div>
          </div>
          
          <!-- Memory Usage -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="p-3 bg-yellow-100 rounded-full">
                <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Memory Usage</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @memory_mb %> MB</p>
                <p class="text-xs text-gray-500"><%= @memory_percentage %>% of 1GB</p>
              </div>
            </div>
          </div>
          
          <!-- Process Count -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="p-3 bg-purple-100 rounded-full">
                <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"></path>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Processes</p>
                <p class="text-2xl font-semibold text-gray-900"><%= @process_count %></p>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Additional Stats -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          <!-- Database Stats -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Database Stats</h3>
            <dl class="grid grid-cols-1 gap-2">
              <div class="flex justify-between">
                <dt class="text-sm text-gray-600">Total Games Recorded</dt>
                <dd class="text-sm font-medium text-gray-900"><%= @db_stats.total_games_recorded %></dd>
              </div>
            </dl>
          </div>
          
          <!-- Rate Limiter Stats -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Rate Limiter</h3>
            <dl class="grid grid-cols-1 gap-2">
              <div class="flex justify-between">
                <dt class="text-sm text-gray-600">Tracked Keys</dt>
                <dd class="text-sm font-medium text-gray-900"><%= @rate_limit_stats.tracked_keys %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-sm text-gray-600">Memory Usage</dt>
                <dd class="text-sm font-medium text-gray-900"><%= Float.round(@rate_limit_stats.memory_bytes / 1024, 2) %> KB</dd>
              </div>
            </dl>
          </div>
        </div>
        
        <!-- Active Games Table -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
            <h3 class="text-lg font-semibold text-gray-900">Active Games</h3>
            <button
              phx-click="refresh"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
            >
              Refresh Now
            </button>
          </div>
          
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Game ID
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Players
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Current Turn
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Started
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for game <- @active_games do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= game.id %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                        game.status == :playing && "bg-green-100 text-green-800",
                        game.status == :waiting && "bg-yellow-100 text-yellow-800",
                        game.status == :finished && "bg-gray-100 text-gray-800"
                      ]}>
                        <%= game.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-900">
                      <div class="text-sm">
                        <%= game.player_count %> players
                      </div>
                      <div class="text-xs text-gray-500">
                        <%= Enum.join(game.players, ", ") %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= game.current_player || "-" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= game.created_at %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                      <button
                        phx-click="stop_game"
                        phx-value-game_id={game.id}
                        class="text-red-600 hover:text-red-900"
                        data-confirm="Are you sure you want to stop this game?"
                      >
                        Stop
                      </button>
                    </td>
                  </tr>
                <% end %>
                
                <%= if @active_games == [] do %>
                  <tr>
                    <td colspan="6" class="px-6 py-4 text-center text-sm text-gray-500">
                      No active games
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
        
        <!-- Auto-refresh notice -->
        <div class="mt-4 text-center text-sm text-gray-500">
          Auto-refreshes every 5 seconds
        </div>
      </div>
    </div>
    """
  end
end