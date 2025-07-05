defmodule Rachel.Games.ReplayRecorder do
  @moduledoc """
  Records game events for replay functionality.
  """

  @type game_event :: %{
          type: atom(),
          timestamp: DateTime.t(),
          player_id: String.t(),
          player_name: String.t(),
          data: map()
        }

  @doc """
  Starts recording a game session.
  """
  def start_recording(game_id, initial_state) do
    events = [
      %{
        type: :game_started,
        timestamp: DateTime.utc_now(),
        player_id: nil,
        player_name: nil,
        data: %{
          game_id: game_id,
          players: extract_player_info(initial_state.players),
          game_state: sanitize_game_state(initial_state)
        }
      }
    ]

    # Store in ETS for fast access during game
    :ets.new(recording_table(game_id), [:named_table, :public, :ordered_set])
    :ets.insert(recording_table(game_id), {0, events})

    {:ok, events}
  end

  @doc """
  Records a game event during play.
  """
  def record_event(game_id, event_type, player_id, player_name, data) do
    event = %{
      type: event_type,
      timestamp: DateTime.utc_now(),
      player_id: player_id,
      player_name: player_name,
      data: data
    }

    table = recording_table(game_id)

    case :ets.lookup(table, 0) do
      [{0, existing_events}] ->
        updated_events = existing_events ++ [event]
        :ets.insert(table, {0, updated_events})
        {:ok, event}

      [] ->
        {:error, :recording_not_started}
    end
  end

  @doc """
  Stops recording and optionally saves the replay.
  """
  def stop_recording(game_id, save_replay? \\ true) do
    table = recording_table(game_id)

    case :ets.lookup(table, 0) do
      [{0, events}] ->
        :ets.delete(table)

        if save_replay? and length(events) > 1 do
          save_replay(game_id, events)
        else
          {:ok, events}
        end

      [] ->
        {:error, :no_recording_found}
    end
  end

  @doc """
  Gets current recording events without stopping.
  """
  def get_current_events(game_id) do
    case :ets.lookup(recording_table(game_id), 0) do
      [{0, events}] -> {:ok, events}
      [] -> {:error, :no_recording_found}
    end
  end

  @doc """
  Records common game events with proper formatting.
  """
  def record_card_play(game_id, player_id, player_name, cards, effects) do
    record_event(game_id, :card_played, player_id, player_name, %{
      cards: format_cards(cards),
      effects: effects,
      card_count: length(cards)
    })
  end

  def record_card_draw(game_id, player_id, player_name, count, reason) do
    record_event(game_id, :card_drawn, player_id, player_name, %{
      count: count,
      reason: reason
    })
  end

  def record_suit_nomination(game_id, player_id, player_name, suit) do
    record_event(game_id, :suit_nominated, player_id, player_name, %{
      suit: suit
    })
  end

  def record_game_won(game_id, player_id, player_name, position, final_state) do
    record_event(game_id, :game_won, player_id, player_name, %{
      position: position,
      remaining_players: extract_player_info(final_state.players),
      game_stats: extract_game_stats(final_state)
    })
  end

  def record_player_join(game_id, player_id, player_name, join_type) do
    record_event(game_id, :player_joined, player_id, player_name, %{
      join_type: join_type
    })
  end

  def record_player_disconnect(game_id, player_id, player_name) do
    record_event(game_id, :player_disconnected, player_id, player_name, %{})
  end

  # Private helper functions

  defp recording_table(game_id), do: :"replay_#{game_id}"

  defp save_replay(game_id, events) do
    metadata = build_metadata(events)

    case Rachel.Games.Replay.create_replay(game_id, events, metadata) do
      {:ok, replay} ->
        # Log successful save
        require Logger
        Logger.info("Saved replay for game #{game_id}: #{replay.title}")
        {:ok, events}

      {:error, reason} ->
        require Logger
        Logger.error("Failed to save replay for game #{game_id}: #{inspect(reason)}")
        # Still return events even if save failed
        {:ok, events}
    end
  end

  defp build_metadata(events) do
    start_event = List.first(events)
    end_event = List.last(events)

    %{
      player_count: count_unique_players(events),
      total_turns: count_turns(events),
      special_cards_played: count_special_cards(events),
      duration_seconds: calculate_duration(start_event, end_event),
      winner_name: extract_winner_name(events),
      player_names: extract_all_player_names(events)
    }
  end

  defp extract_player_info(players) do
    Enum.map(players, fn player ->
      %{
        id: player.id,
        name: player.name,
        is_ai: player.is_ai,
        hand_size: length(player.hand)
      }
    end)
  end

  defp sanitize_game_state(state) do
    # Remove sensitive or large data that's not needed for replay
    %{
      status: state.status,
      direction: state.direction,
      current_player_index: state.current_player_index,
      pending_pickups: state.pending_pickups,
      pending_skips: state.pending_skips,
      nominated_suit: state.nominated_suit
    }
  end

  defp format_cards(cards) do
    Enum.map(cards, fn card ->
      %{rank: card.rank, suit: card.suit}
    end)
  end

  defp extract_game_stats(state) do
    case Map.get(state, :stats) do
      %{game_stats: stats} -> stats
      _ -> %{}
    end
  end

  defp count_unique_players(events) do
    events
    |> Enum.map(& &1.player_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp count_turns(events) do
    Enum.count(events, fn event ->
      event.type in [:card_played, :card_drawn]
    end)
  end

  defp count_special_cards(events) do
    Enum.count(events, fn event ->
      case event do
        %{type: :card_played, data: %{effects: effects}} when effects != [] -> true
        _ -> false
      end
    end)
  end

  defp calculate_duration(start_event, end_event) do
    case {start_event, end_event} do
      {%{timestamp: start}, %{timestamp: finish}} ->
        DateTime.diff(finish, start, :second)

      _ ->
        0
    end
  end

  defp extract_winner_name(events) do
    win_event =
      Enum.find(events, fn event ->
        event.type == :game_won and Map.get(event.data, :position) == 1
      end)

    case win_event do
      %{player_name: name} -> name
      _ -> nil
    end
  end

  defp extract_all_player_names(events) do
    events
    |> Enum.map(& &1.player_name)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
  end
end
