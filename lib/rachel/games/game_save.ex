defmodule Rachel.Games.GameSave do
  @moduledoc """
  Handles saving and loading game state to/from storage.
  Uses :ets for simple in-memory persistence.
  """

  alias Rachel.Games.Game

  @table_name :rachel_saved_games

  def start_link do
    case :ets.info(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:set, :public, :named_table])
        {:ok, self()}

      _ ->
        {:ok, self()}
    end
  end

  def save_game(%Game{} = game, save_name \\ nil) do
    save_name = save_name || generate_save_name(game)
    timestamp = DateTime.utc_now()

    save_data = %{
      game: game,
      saved_at: timestamp,
      save_name: save_name
    }

    :ets.insert(@table_name, {save_name, save_data})
    {:ok, save_name}
  rescue
    e -> {:error, e}
  end

  def load_game(save_name) do
    case :ets.lookup(@table_name, save_name) do
      [{^save_name, save_data}] ->
        {:ok, save_data.game}

      [] ->
        {:error, :not_found}
    end
  end

  def list_saved_games do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {save_name, save_data} ->
      %{
        name: save_name,
        saved_at: save_data.saved_at,
        players: length(save_data.game.players),
        status: save_data.game.status,
        winners: save_data.game.winners,
        turns: get_turn_count(save_data.game)
      }
    end)
    |> Enum.sort_by(& &1.saved_at, {:desc, DateTime})
  end

  def delete_save(save_name) do
    case :ets.delete(@table_name, save_name) do
      true -> :ok
      false -> {:error, :not_found}
    end
  end

  def auto_save_game(%Game{} = game) do
    save_name = "autosave_#{game.id}"
    save_game(game, save_name)
  end

  def load_autosave(game_id) do
    save_name = "autosave_#{game_id}"
    load_game(save_name)
  end

  def export_game(%Game{} = game) do
    game_data = %{
      version: "1.0",
      exported_at: DateTime.utc_now(),
      game: serialize_game(game)
    }

    {:ok, Jason.encode!(game_data, pretty: true)}
  rescue
    e -> {:error, e}
  end

  def import_game(json_data) when is_binary(json_data) do
    case Jason.decode(json_data) do
      {:ok, %{"game" => game_data}} ->
        case deserialize_game(game_data) do
          {:ok, game} -> {:ok, game}
          {:error, reason} -> {:error, reason}
        end

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  defp generate_save_name(%Game{players: players, id: id}) do
    player_names =
      players
      |> Enum.filter(&(!&1.is_ai))
      |> Enum.map(& &1.name)
      |> case do
        [] -> ["AI_Game"]
        names -> names
      end
      |> Enum.join("_")

    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{player_names}_#{String.slice(id, 0, 4)}_#{timestamp}"
  end

  defp get_turn_count(%Game{stats: nil}), do: 0
  defp get_turn_count(%Game{stats: stats}), do: stats.game_stats.total_turns

  defp serialize_game(%Game{} = game) do
    Map.from_struct(game)
    |> Map.update(:stats, nil, fn
      nil -> nil
      stats -> Map.from_struct(stats)
    end)
    |> Map.update(:deck, %{}, fn deck ->
      Map.from_struct(deck)
    end)
    |> Map.update(:players, [], fn players ->
      Enum.map(players, &Map.from_struct/1)
    end)
    |> serialize_cards()
  end

  defp serialize_cards(game_data) do
    game_data
    |> serialize_current_card()
    |> serialize_deck()
    |> serialize_players()
  end

  defp serialize_current_card(game_data) do
    Map.update(game_data, :current_card, nil, fn
      nil -> nil
      card -> Map.from_struct(card)
    end)
  end

  defp serialize_deck(game_data) do
    Map.update(game_data, :deck, %{}, fn deck ->
      deck
      |> Map.update(:cards, [], &serialize_card_list/1)
      |> Map.update(:discarded, [], &serialize_card_list/1)
    end)
  end

  defp serialize_players(game_data) do
    Map.update(game_data, :players, [], fn players ->
      Enum.map(players, &serialize_player/1)
    end)
  end

  defp serialize_player(player) do
    Map.update(player, :hand, [], &serialize_card_list/1)
  end

  defp serialize_card_list(cards) do
    Enum.map(cards, &Map.from_struct/1)
  end

  defp deserialize_game(game_data) when is_map(game_data) do
    game =
      struct(Game, game_data)
      |> deserialize_cards()
      |> deserialize_stats()

    {:ok, game}
  rescue
    error -> {:error, {:deserialization_failed, error}}
  end

  defp deserialize_cards(%Game{} = game) do
    game
    |> deserialize_current_card()
    |> deserialize_deck()
    |> deserialize_players()
  end

  defp deserialize_current_card(game) do
    Map.update(game, :current_card, nil, fn
      nil -> nil
      card_data -> struct(Rachel.Games.Card, card_data)
    end)
  end

  defp deserialize_deck(game) do
    Map.update(game, :deck, %{}, fn deck_data ->
      struct(Rachel.Games.Deck, deck_data)
      |> Map.update(:cards, [], &deserialize_card_list/1)
      |> Map.update(:discarded, [], &deserialize_card_list/1)
    end)
  end

  defp deserialize_players(game) do
    Map.update(game, :players, [], fn players ->
      Enum.map(players, &deserialize_player/1)
    end)
  end

  defp deserialize_player(player_data) do
    Map.update(player_data, :hand, [], &deserialize_card_list/1)
  end

  defp deserialize_card_list(cards) do
    Enum.map(cards, &struct(Rachel.Games.Card, &1))
  end

  defp deserialize_stats(%Game{stats: nil} = game), do: game

  defp deserialize_stats(%Game{stats: stats_data} = game) when is_map(stats_data) do
    stats = struct(Rachel.Games.Stats, stats_data)
    %{game | stats: stats}
  end
end
