defmodule Rachel.Repo.Migrations.CreateGameStates do
  use Ecto.Migration

  def change do
    create table(:game_states) do
      add :game_id, :string, null: false
      add :game_data, :text, null: false
      add :status, :string, null: false, default: "waiting"
      add :player_count, :integer, null: false, default: 0
      add :host_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_states, [:game_id])
    create index(:game_states, [:status])
    create index(:game_states, [:updated_at])
  end
end
