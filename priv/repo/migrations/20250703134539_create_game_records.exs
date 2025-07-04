defmodule Rachel.Repo.Migrations.CreateGameRecords do
  use Ecto.Migration

  def change do
    create table(:game_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, :string, null: false
      add :status, :string, null: false, default: "completed"
      add :winner_id, :string
      add :total_turns, :integer, null: false, default: 0
      add :total_cards_played, :integer, null: false, default: 0
      add :total_cards_drawn, :integer, null: false, default: 0
      add :special_effects_triggered, :integer, null: false, default: 0
      add :direction_changes, :integer, null: false, default: 0
      add :suit_nominations, :integer, null: false, default: 0
      add :game_duration_seconds, :integer
      add :finish_positions, {:array, :string}, default: []
      add :player_names, :map, default: %{}
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime
      
      timestamps()
    end

    create index(:game_records, [:game_id])
    create index(:game_records, [:winner_id])
    create index(:game_records, [:status])
    create index(:game_records, [:started_at])
  end
end
