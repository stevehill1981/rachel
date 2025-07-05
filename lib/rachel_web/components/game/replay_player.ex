defmodule RachelWeb.Components.Game.ReplayPlayer do
  @moduledoc """
  Game replay player with playback controls and timeline scrubbing.
  """
  use Phoenix.Component

  attr :replay, :map, required: true
  attr :current_event_index, :integer, default: 0
  attr :is_playing, :boolean, default: false
  attr :playback_speed, :float, default: 1.0
  attr :show_timeline, :boolean, default: true
  attr :show_player_hands, :boolean, default: false

  def replay_player(assigns) do
    assigns = assign(assigns, :events, assigns.replay.game_data || [])

    assigns =
      assign(
        assigns,
        :current_event,
        get_current_event(assigns.events, assigns.current_event_index)
      )

    assigns =
      assign(
        assigns,
        :game_state,
        reconstruct_game_state(assigns.events, assigns.current_event_index)
      )

    ~H"""
    <div
      class="replay-player bg-gradient-to-br from-gray-900 to-gray-800 min-h-screen text-white"
      phx-hook="ReplayPlayer"
      id="replay-player"
      data-replay-id={@replay.id}
      data-total-events={length(@events)}
    >
      
    <!-- Replay Header -->
      <div class="bg-black/30 p-4 border-b border-gray-700">
        <div class="max-w-7xl mx-auto flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">{@replay.title}</h1>
            <p class="text-gray-300 text-sm">{@replay.description}</p>
            <div class="flex items-center space-x-4 mt-2 text-sm text-gray-400">
              <span>👥 {Enum.join(@replay.player_names, ", ")}</span>
              <span>⏱️ {format_duration(@replay.duration_seconds)}</span>
              <span>🎯 {format_moves(@replay.total_moves)}</span>
              <span>👁️ {@replay.view_count} views</span>
            </div>
          </div>

          <div class="flex items-center space-x-3">
            <.replay_speed_selector speed={@playback_speed} />
            <.replay_toggle_button active={@show_player_hands} icon="eye" event="toggle_hands" />
            <.replay_toggle_button active={@show_timeline} icon="timeline" event="toggle_timeline" />
          </div>
        </div>
      </div>
      
    <!-- Replay Controls -->
      <div class="bg-black/20 p-4 border-b border-gray-700">
        <div class="max-w-7xl mx-auto">
          <.replay_controls
            is_playing={@is_playing}
            current_index={@current_event_index}
            total_events={length(@events)}
            current_event={@current_event}
          />

          <%= if @show_timeline do %>
            <.replay_timeline
              events={@events}
              current_index={@current_event_index}
              total_events={length(@events)}
            />
          <% end %>
        </div>
      </div>
      
    <!-- Game State Display -->
      <div class="flex-1 p-4">
        <div class="max-w-7xl mx-auto">
          <%= if @game_state do %>
            <.game_state_display
              game_state={@game_state}
              current_event={@current_event}
              show_player_hands={@show_player_hands}
            />
          <% else %>
            <div class="text-center py-12">
              <p class="text-gray-400">No game state available for this event</p>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Event Details Panel -->
      <div class="bg-black/30 p-4 border-t border-gray-700">
        <div class="max-w-7xl mx-auto">
          <.event_details_panel current_event={@current_event} index={@current_event_index} />
        </div>
      </div>
    </div>
    """
  end

  attr :is_playing, :boolean, required: true
  attr :current_index, :integer, required: true
  attr :total_events, :integer, required: true
  attr :current_event, :any, required: true

  defp replay_controls(assigns) do
    ~H"""
    <div class="flex items-center justify-center space-x-4">
      <!-- Jump to Start -->
      <button
        phx-click="replay_jump_start"
        class="p-2 rounded-lg bg-gray-700 hover:bg-gray-600 transition-colors"
        title="Jump to start"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M11 19l-7-7 7-7m8 14l-7-7 7-7"
          />
        </svg>
      </button>
      
    <!-- Previous Event -->
      <button
        phx-click="replay_prev"
        disabled={@current_index <= 0}
        class="p-2 rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        title="Previous event"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
      </button>
      
    <!-- Play/Pause -->
      <button
        phx-click={if @is_playing, do: "replay_pause", else: "replay_play"}
        class="p-3 rounded-full bg-blue-600 hover:bg-blue-700 transition-colors"
        title={if @is_playing, do: "Pause", else: "Play"}
      >
        <%= if @is_playing do %>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6" />
          </svg>
        <% else %>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1"
            />
          </svg>
        <% end %>
      </button>
      
    <!-- Next Event -->
      <button
        phx-click="replay_next"
        disabled={@current_index >= @total_events - 1}
        class="p-2 rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        title="Next event"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </button>
      
    <!-- Jump to End -->
      <button
        phx-click="replay_jump_end"
        class="p-2 rounded-lg bg-gray-700 hover:bg-gray-600 transition-colors"
        title="Jump to end"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 5l7 7-7 7M5 5l7 7-7 7"
          />
        </svg>
      </button>
      
    <!-- Progress Display -->
      <div class="ml-4 text-sm text-gray-400">
        Event {@current_index + 1} of {@total_events}
      </div>
    </div>
    """
  end

  attr :events, :list, required: true
  attr :current_index, :integer, required: true
  attr :total_events, :integer, required: true

  defp replay_timeline(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="relative">
        <!-- Timeline Track -->
        <div
          class="w-full h-2 bg-gray-700 rounded-full cursor-pointer"
          phx-click="replay_seek"
          phx-hook="TimelineSeeker"
          id="timeline-track"
        >
          
    <!-- Progress -->
          <div
            class="h-full bg-blue-500 rounded-full transition-all duration-300"
            style={"width: #{if @total_events > 0, do: (@current_index / (@total_events - 1)) * 100, else: 0}%"}
          >
          </div>
          
    <!-- Event Markers -->
          <%= for {event, index} <- Enum.with_index(@events) do %>
            <div
              class={[
                "absolute top-0 w-2 h-2 rounded-full transform -translate-x-1/2 cursor-pointer",
                event_marker_class(event),
                index == @current_index && "ring-2 ring-white scale-150"
              ]}
              style={"left: #{if @total_events > 1, do: (index / (@total_events - 1)) * 100, else: 0}%"}
              title={format_event_tooltip(event)}
              phx-click="replay_jump_to"
              phx-value-index={index}
            >
            </div>
          <% end %>
        </div>
        
    <!-- Time Labels -->
        <div class="flex justify-between mt-2 text-xs text-gray-500">
          <span>Start</span>
          <span>End</span>
        </div>
      </div>
    </div>
    """
  end

  attr :speed, :float, required: true

  defp replay_speed_selector(assigns) do
    ~H"""
    <div class="flex items-center space-x-1 bg-gray-700 rounded-lg p-1">
      <%= for speed <- [0.5, 1.0, 2.0, 4.0] do %>
        <button
          phx-click="replay_set_speed"
          phx-value-speed={speed}
          class={[
            "px-2 py-1 rounded text-xs font-medium transition-colors",
            @speed == speed && "bg-blue-600 text-white",
            @speed != speed && "text-gray-300 hover:text-white"
          ]}
        >
          {format_speed(speed)}
        </button>
      <% end %>
    </div>
    """
  end

  attr :active, :boolean, required: true
  attr :icon, :string, required: true
  attr :event, :string, required: true

  defp replay_toggle_button(assigns) do
    ~H"""
    <button
      phx-click={@event}
      class={[
        "p-2 rounded-lg transition-colors",
        @active && "bg-blue-600 text-white",
        !@active && "bg-gray-700 text-gray-300 hover:text-white"
      ]}
    >
      <%= case @icon do %>
        <% "eye" -> %>
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
            />
          </svg>
        <% "timeline" -> %>
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"
            />
          </svg>
      <% end %>
    </button>
    """
  end

  attr :game_state, :map, required: true
  attr :current_event, :any, required: true
  attr :show_player_hands, :boolean, required: true

  defp game_state_display(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Current Event Highlight -->
      <%= if @current_event do %>
        <div class="bg-blue-600/20 border border-blue-400/30 rounded-xl p-4">
          <div class="flex items-center space-x-3">
            <div class="w-3 h-3 bg-blue-500 rounded-full animate-pulse"></div>
            <div>
              <h3 class="font-semibold">{format_event_title(@current_event)}</h3>
              <p class="text-sm text-gray-300">{format_event_description(@current_event)}</p>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Game Board Recreation -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Players -->
        <div class="lg:col-span-2">
          <h3 class="text-lg font-semibold mb-4">Players</h3>
          <div class="space-y-3">
            <%= for player <- @game_state.players do %>
              <.replay_player_card
                player={player}
                is_current={player.id == get_current_player_id(@game_state)}
                show_hands={@show_player_hands}
              />
            <% end %>
          </div>
        </div>
        
    <!-- Game Info -->
        <div>
          <h3 class="text-lg font-semibold mb-4">Game State</h3>
          <div class="bg-white/10 rounded-lg p-4 space-y-3">
            <div class="flex justify-between">
              <span class="text-gray-400">Status:</span>
              <span class="text-white capitalize">{@game_state.status}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-400">Direction:</span>
              <span class="text-white">
                {if @game_state.direction == :clockwise,
                  do: "↻ Clockwise",
                  else: "↺ Counter-clockwise"}
              </span>
            </div>
            <%= if @game_state.pending_pickups > 0 do %>
              <div class="flex justify-between">
                <span class="text-gray-400">Pending Pickups:</span>
                <span class="text-red-400">+{@game_state.pending_pickups}</span>
              </div>
            <% end %>
            <%= if @game_state.pending_skips > 0 do %>
              <div class="flex justify-between">
                <span class="text-gray-400">Pending Skips:</span>
                <span class="text-yellow-400">{@game_state.pending_skips}</span>
              </div>
            <% end %>
            <%= if Map.get(@game_state, :nominated_suit) do %>
              <div class="flex justify-between">
                <span class="text-gray-400">Nominated Suit:</span>
                <span class="text-purple-400">{format_suit(@game_state.nominated_suit)}</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :current_event, :any, required: true
  attr :index, :integer, required: true

  defp event_details_panel(assigns) do
    ~H"""
    <div class="bg-white/5 rounded-lg p-4">
      <h3 class="text-sm font-semibold text-gray-300 mb-2">Event Details</h3>
      <%= if @current_event do %>
        <div class="text-sm space-y-1">
          <div>
            <span class="text-gray-400">Type:</span>
            <span class="text-white">{@current_event.type}</span>
          </div>
          <div>
            <span class="text-gray-400">Time:</span>
            <span class="text-white">{format_timestamp(@current_event.timestamp)}</span>
          </div>
          <%= if @current_event.player_name do %>
            <div>
              <span class="text-gray-400">Player:</span>
              <span class="text-white">{@current_event.player_name}</span>
            </div>
          <% end %>
          <%= if @current_event.data && map_size(@current_event.data) > 0 do %>
            <div class="mt-2">
              <span class="text-gray-400">Data:</span>
              <pre class="text-xs text-gray-300 mt-1 bg-black/30 p-2 rounded overflow-x-auto">{Jason.encode!(@current_event.data, pretty: true)}</pre>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-gray-400 text-sm">No event selected</p>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp get_current_event(events, index) do
    Enum.at(events, index)
  end

  defp reconstruct_game_state(events, current_index) do
    # This would reconstruct the game state up to the current event
    # For now, return a mock state based on the current event
    current_event = Enum.at(events, current_index)

    case current_event do
      %{data: %{game_state: state}} -> state
      _ -> build_mock_game_state(events, current_index)
    end
  end

  defp build_mock_game_state(events, _current_index) do
    # Extract player info from the first event
    start_event = List.first(events)

    case start_event do
      %{data: %{players: players}} ->
        %{
          status: :playing,
          direction: :clockwise,
          current_player_index: 0,
          pending_pickups: 0,
          pending_skips: 0,
          nominated_suit: nil,
          players: players
        }

      _ ->
        %{
          status: :playing,
          direction: :clockwise,
          current_player_index: 0,
          pending_pickups: 0,
          pending_skips: 0,
          nominated_suit: nil,
          players: []
        }
    end
  end

  defp get_current_player_id(game_state) do
    case Enum.at(game_state.players, game_state.current_player_index) do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end

  defp format_moves(count), do: "#{count} moves"

  defp format_speed(1.0), do: "1x"
  defp format_speed(speed), do: "#{speed}x"

  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} -> Calendar.strftime(timestamp, "%H:%M:%S")
      _ -> "00:00:00"
    end
  end

  defp event_marker_class(event) do
    case event.type do
      :game_started -> "bg-green-500"
      :card_played -> "bg-blue-500"
      :card_drawn -> "bg-yellow-500"
      :suit_nominated -> "bg-purple-500"
      :game_won -> "bg-red-500"
      _ -> "bg-gray-500"
    end
  end

  defp format_event_tooltip(event) do
    case event.type do
      :card_played -> "#{event.player_name} played cards"
      :card_drawn -> "#{event.player_name} drew cards"
      :suit_nominated -> "#{event.player_name} nominated suit"
      :game_won -> "#{event.player_name} won!"
      _ -> "#{event.type}"
    end
  end

  defp format_event_title(event) do
    case event.type do
      :game_started -> "🎮 Game Started"
      :card_played -> "🃏 Cards Played"
      :card_drawn -> "📥 Cards Drawn"
      :suit_nominated -> "🎯 Suit Nominated"
      :game_won -> "🏆 Game Won"
      :player_joined -> "👋 Player Joined"
      :player_disconnected -> "📵 Player Disconnected"
      _ -> "#{event.type}" |> to_string() |> String.capitalize()
    end
  end

  defp format_event_description(event) do
    case event.type do
      :card_played ->
        cards_text =
          case Map.get(event.data, :card_count, 1) do
            1 -> "1 card"
            n -> "#{n} cards"
          end

        "#{event.player_name} played #{cards_text}"

      :card_drawn ->
        count = Map.get(event.data, :count, 1)
        "#{event.player_name} drew #{count} cards"

      :suit_nominated ->
        suit = Map.get(event.data, :suit, "unknown")
        "#{event.player_name} nominated #{suit}"

      :game_won ->
        "#{event.player_name} won the game!"

      _ ->
        if event.player_name do
          "Action by #{event.player_name}"
        else
          "Game event"
        end
    end
  end

  defp format_suit(:hearts), do: "Hearts ♥"
  defp format_suit(:diamonds), do: "Diamonds ♦"
  defp format_suit(:clubs), do: "Clubs ♣"
  defp format_suit(:spades), do: "Spades ♠"
  defp format_suit(suit), do: to_string(suit)

  attr :player, :map, required: true
  attr :is_current, :boolean, required: true
  attr :show_hands, :boolean, required: true

  defp replay_player_card(assigns) do
    ~H"""
    <div class={[
      "p-3 rounded-lg border transition-all",
      @is_current && "bg-blue-500/20 border-blue-400",
      !@is_current && "bg-white/5 border-gray-600"
    ]}>
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center text-white text-sm font-bold">
            {String.first(@player.name)}
          </div>
          <div>
            <p class="text-white font-medium">{@player.name}</p>
            <p class="text-gray-400 text-xs">
              {Map.get(@player, :hand_size, 0)} cards
              <%= if @player.is_ai do %>
                • AI
              <% end %>
            </p>
          </div>
        </div>

        <%= if @is_current do %>
          <span class="px-2 py-1 bg-blue-500 text-white rounded text-xs font-medium">
            Current
          </span>
        <% end %>
      </div>
    </div>
    """
  end
end
