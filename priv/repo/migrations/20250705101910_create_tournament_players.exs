defmodule Rachel.Repo.Migrations.CreateTournamentPlayers do
  use Ecto.Migration

  def change do
    create table(:tournament_players) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :player_id, :string, null: false
      add :player_name, :string, null: false
      add :seed, :integer
      add :status, :string, null: false, default: "registered"
      add :eliminated_round, :integer
      add :final_position, :integer
      add :points, :integer, default: 0
      add :wins, :integer, default: 0
      add :losses, :integer, default: 0
      add :byes, :integer, default: 0
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:tournament_players, [:tournament_id, :player_id])
    create index(:tournament_players, [:tournament_id])
    create index(:tournament_players, [:player_id])
    create index(:tournament_players, [:status])
    create index(:tournament_players, [:seed])
    create index(:tournament_players, [:points])
  end
end
