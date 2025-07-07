defmodule RachelWeb.PracticeLive do
  @moduledoc """
  Practice mode interface where players can choose AI opponents and settings.
  """

  use RachelWeb, :live_view
  alias Rachel.AI.{EnhancedAIPlayer, Personality}
  alias Rachel.Games.GameServer

  @impl true
  def mount(_params, session, socket) do
    personalities = Personality.all_personalities()

    # Smart defaults to reduce friction
    player_name = session[:player_name] || generate_friendly_name()

    default_opponents = [
      Personality.get_personality(:conservative),
      Personality.get_personality(:strategic)
    ]

    socket =
      socket
      |> assign(:page_title, "Practice Mode")
      |> assign(:personalities, personalities)
      |> assign(:selected_opponents, default_opponents)
      |> assign(:max_opponents, 3)
      |> assign(:game_started, false)
      |> assign(:player_name, player_name)
      |> assign(:difficulty_level, :mixed)
      |> assign(:show_advanced_options, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_player_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :player_name, name)}
  end

  @impl true
  def handle_event("select_personality", %{"type" => type}, socket) do
    personality_type = String.to_existing_atom(type)
    selected = socket.assigns.selected_opponents

    if length(selected) < socket.assigns.max_opponents and
         not Enum.any?(selected, &(&1.type == personality_type)) do
      personality = Personality.get_personality(personality_type)
      updated_selected = selected ++ [personality]
      {:noreply, assign(socket, :selected_opponents, updated_selected)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_opponent", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    updated_selected = List.delete_at(socket.assigns.selected_opponents, index)
    {:noreply, assign(socket, :selected_opponents, updated_selected)}
  end

  @impl true
  def handle_event("add_random_opponents", _params, socket) do
    selected = socket.assigns.selected_opponents
    needed = socket.assigns.max_opponents - length(selected)

    if needed > 0 do
      available_types =
        socket.assigns.personalities
        |> Enum.map(& &1.type)
        |> Enum.filter(&(not Enum.any?(selected, fn s -> s.type == &1 end)))

      random_personalities =
        available_types
        |> Enum.shuffle()
        |> Enum.take(needed)
        |> Enum.map(&Personality.get_personality/1)

      updated_selected = selected ++ random_personalities
      {:noreply, assign(socket, :selected_opponents, updated_selected)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_opponents", _params, socket) do
    {:noreply, assign(socket, :selected_opponents, [])}
  end

  @impl true
  def handle_event("set_difficulty", %{"level" => level}, socket) do
    difficulty = String.to_existing_atom(level)
    {:noreply, assign(socket, :difficulty_level, difficulty)}
  end

  @impl true
  def handle_event("toggle_advanced_options", _params, socket) do
    {:noreply, assign(socket, :show_advanced_options, not socket.assigns.show_advanced_options)}
  end

  @impl true
  def handle_event("start_practice_game", _params, socket) do
    if socket.assigns.player_name != "" and length(socket.assigns.selected_opponents) > 0 do
      # Check rate limit
      player_key = "game:player:#{socket.assigns.player_id}"
      
      case Rachel.RateLimiter.check_rate(player_key, max_requests: 10, window_ms: :timer.minutes(5)) do
        {:ok, _remaining} ->
          # Create game with AI players
          game_id = generate_game_id()

          # Create human player
          human_player = %{
            id: "human_player",
            name: socket.assigns.player_name,
            is_ai: false
          }

          # Create AI players with selected personalities
          ai_players =
            socket.assigns.selected_opponents
            |> Enum.with_index()
            |> Enum.map(fn {personality, _index} ->
              EnhancedAIPlayer.new_ai_player(personality.name, personality.type)
            end)

          _all_players = [human_player | ai_players]

          # Start the game server
          case GameServer.start_link(game_id: game_id) do
            {:ok, _pid} ->
              # Add human player
              GameServer.join_game(game_id, human_player.id, human_player.name)

              # Add AI players
              Enum.each(ai_players, fn ai_player ->
                GameServer.add_ai_player(game_id, ai_player.name)
              end)

              # Start the game
              case GameServer.start_game(game_id, human_player.id) do
                {:ok, _game} ->
                  {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}

                {:error, reason} ->
                  {:noreply, put_flash(socket, :error, "Failed to start game: #{inspect(reason)}")}
              end

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Failed to create game: #{inspect(reason)}")}
          end
        
        {:error, :rate_limited} ->
          {:noreply, put_flash(socket, :error, "You're creating games too quickly. Please wait a few minutes before trying again.")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Please enter your name and select at least one opponent")}
    end
  end

  @impl true
  def handle_event("quick_start", %{"setup" => setup}, socket) do
    {player_name, opponents} =
      case setup do
        "beginner" ->
          {"Player", [Personality.get_personality(:conservative)]}

        "intermediate" ->
          {"Player",
           [
             Personality.get_personality(:conservative),
             Personality.get_personality(:strategic)
           ]}

        "advanced" ->
          {"Player",
           [
             Personality.get_personality(:aggressive),
             Personality.get_personality(:strategic),
             Personality.get_personality(:bluffer)
           ]}

        "chaos" ->
          {"Player",
           [
             Personality.get_personality(:chaotic),
             Personality.get_personality(:aggressive),
             Personality.get_personality(:bluffer)
           ]}
      end

    socket =
      socket
      |> assign(:player_name, player_name)
      |> assign(:selected_opponents, opponents)

    {:noreply, socket}
  end

  # Template helpers

  defp difficulty_description(:easy), do: "AI makes more mistakes and thinks less strategically"
  defp difficulty_description(:normal), do: "Balanced AI with authentic personality traits"
  defp difficulty_description(:hard), do: "AI plays optimally with enhanced strategic thinking"
  defp difficulty_description(:mixed), do: "Each AI uses its natural difficulty level"

  defp personality_color(type) do
    case type do
      :aggressive -> "bg-red-500"
      :conservative -> "bg-blue-500"
      :strategic -> "bg-purple-500"
      :chaotic -> "bg-orange-500"
      :adaptive -> "bg-green-500"
      :bluffer -> "bg-gray-600"
    end
  end

  defp personality_icon(type) do
    case type do
      :aggressive -> "⚔️"
      :conservative -> "🛡️"
      :strategic -> "🧠"
      :chaotic -> "🌪️"
      :adaptive -> "🔄"
      :bluffer -> "🎭"
    end
  end

  defp trait_bar_width(value) do
    "width: #{value * 100}%"
  end

  defp trait_color(value) do
    cond do
      value >= 0.8 -> "bg-red-500"
      value >= 0.6 -> "bg-yellow-500"
      value >= 0.4 -> "bg-blue-500"
      true -> "bg-gray-500"
    end
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end

  defp generate_friendly_name do
    adjectives = ["Happy", "Clever", "Lucky", "Swift", "Bright", "Cheerful", "Bold", "Wise"]
    nouns = ["Player", "Gamer", "Friend", "Explorer", "Hero", "Champion", "Ace", "Star"]

    adjective = Enum.random(adjectives)
    noun = Enum.random(nouns)

    "#{adjective} #{noun}"
  end
end
