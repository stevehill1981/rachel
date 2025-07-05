defmodule Rachel.Repo.Migrations.CreateTournamentMatches do
  use Ecto.Migration

  def change do
    create table(:tournament_matches) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :round, :integer, null: false
      add :match_number, :integer, null: false
      add :bracket_type, :string, null: false, default: "winners"
      add :status, :string, null: false, default: "pending"
      add :player1_id, :string
      add :player2_id, :string
      add :winner_id, :string
      add :loser_id, :string
      add :game_id, :string
      add :scheduled_time, :utc_datetime
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :score, :map, default: %{}
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:tournament_matches, [:tournament_id])
    create index(:tournament_matches, [:round])
    create index(:tournament_matches, [:status])
    create index(:tournament_matches, [:bracket_type])
    create index(:tournament_matches, [:player1_id])
    create index(:tournament_matches, [:player2_id])
    create index(:tournament_matches, [:winner_id])
    create index(:tournament_matches, [:scheduled_time])

    create unique_index(:tournament_matches, [
             :tournament_id,
             :round,
             :match_number,
             :bracket_type
           ])
  end
end
