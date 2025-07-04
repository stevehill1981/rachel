defmodule Rachel.Accounts.GameRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_records" do
    field :game_id, :string
    field :status, :string, default: "completed"
    field :winner_id, :string
    field :total_turns, :integer, default: 0
    field :total_cards_played, :integer, default: 0
    field :total_cards_drawn, :integer, default: 0
    field :special_effects_triggered, :integer, default: 0
    field :direction_changes, :integer, default: 0
    field :suit_nominations, :integer, default: 0
    field :game_duration_seconds, :integer
    field :finish_positions, {:array, :string}, default: []
    field :player_names, :map, default: %{}
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    has_many :player_stats, Rachel.Accounts.PlayerStats

    timestamps()
  end

  @doc false
  def changeset(game_record, attrs) do
    game_record
    |> cast(attrs, [
      :game_id,
      :status,
      :winner_id,
      :total_turns,
      :total_cards_played,
      :total_cards_drawn,
      :special_effects_triggered,
      :direction_changes,
      :suit_nominations,
      :game_duration_seconds,
      :finish_positions,
      :player_names,
      :started_at,
      :ended_at
    ])
    |> validate_required([:game_id, :status])
    |> validate_inclusion(:status, ["completed", "abandoned"])
    |> unique_constraint(:game_id)
  end
end
