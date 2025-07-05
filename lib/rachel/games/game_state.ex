defmodule Rachel.Games.GameState do
  @moduledoc """
  Database schema for persisting game state across deployments.
  Provides validation and security for stored game data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ["waiting", "playing", "finished", "cancelled"]
  @max_players 8
  # 100KB limit for game data
  @max_game_data_size 100_000

  schema "game_states" do
    field :game_id, :string
    field :game_data, :string
    field :status, :string
    field :player_count, :integer
    field :host_id, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating game state with comprehensive validation.
  """
  def changeset(game_state, attrs) do
    game_state
    |> cast(attrs, [:game_id, :game_data, :status, :player_count, :host_id])
    |> validate_required([:game_id, :game_data, :status])
    |> validate_game_id()
    |> validate_status()
    |> validate_player_count()
    |> validate_game_data_size()
    |> validate_host_id()
    |> validate_game_data_integrity()
    |> unique_constraint(:game_id)
  end

  @doc """
  Validates that the game data can be safely deserialized.
  """
  def validate_game_data_integrity(changeset) do
    case get_field(changeset, :game_data) do
      nil ->
        changeset

      game_data ->
        case Jason.decode(game_data) do
          {:ok, decoded} ->
            if valid_game_structure?(decoded) do
              changeset
            else
              add_error(changeset, :game_data, "Invalid game data structure")
            end

          {:error, _} ->
            add_error(changeset, :game_data, "Invalid JSON format")
        end
    end
  end

  # Private validation functions

  defp validate_game_id(changeset) do
    changeset
    |> validate_length(:game_id, min: 5, max: 100)
    |> validate_format(:game_id, ~r/^[a-zA-Z0-9_-]+$/,
      message: "can only contain letters, numbers, underscores, and hyphens"
    )
  end

  defp validate_status(changeset) do
    validate_inclusion(changeset, :status, @valid_statuses,
      message: "must be one of: #{Enum.join(@valid_statuses, ", ")}"
    )
  end

  defp validate_player_count(changeset) do
    changeset
    |> validate_number(:player_count, greater_than_or_equal_to: 0)
    |> validate_number(:player_count, less_than_or_equal_to: @max_players)
  end

  defp validate_game_data_size(changeset) do
    case get_field(changeset, :game_data) do
      nil ->
        changeset

      game_data when byte_size(game_data) > @max_game_data_size ->
        add_error(changeset, :game_data, "exceeds maximum size limit")

      _ ->
        changeset
    end
  end

  defp validate_host_id(changeset) do
    case get_field(changeset, :host_id) do
      nil ->
        changeset

      _host_id ->
        validate_format(changeset, :host_id, ~r/^[a-zA-Z0-9_-]+$/,
          message: "can only contain letters, numbers, underscores, and hyphens"
        )
    end
  end

  defp valid_game_structure?(data) when is_map(data) do
    required_fields = ["id", "players", "status"]
    Enum.all?(required_fields, &Map.has_key?(data, &1))
  end

  defp valid_game_structure?(_), do: false
end
