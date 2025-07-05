defmodule Rachel.Repo.Migrations.CreateGameReplays do
  use Ecto.Migration

  def change do
    create table(:game_replays) do
      add :game_id, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :duration_seconds, :integer
      add :total_moves, :integer
      add :player_names, {:array, :string}, default: []
      add :winner_name, :string
      # JSON-encoded game events
      add :game_data, :text, null: false
      add :metadata, :map, default: %{}
      add :is_public, :boolean, default: false
      add :view_count, :integer, default: 0

      timestamps()
    end

    create unique_index(:game_replays, [:game_id])
    create index(:game_replays, [:is_public])
    create index(:game_replays, [:view_count])
    create index(:game_replays, [:inserted_at])
    create index(:game_replays, [:winner_name])
  end
end
