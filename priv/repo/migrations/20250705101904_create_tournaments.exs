defmodule Rachel.Repo.Migrations.CreateTournaments do
  use Ecto.Migration

  def change do
    create table(:tournaments) do
      add :name, :string, null: false
      add :description, :text
      add :format, :string, null: false
      add :status, :string, null: false, default: "registration"
      add :max_players, :integer, null: false
      add :entry_fee, :integer, default: 0
      add :prize_pool, :integer, default: 0
      add :registration_deadline, :utc_datetime
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :current_round, :integer, default: 0
      add :total_rounds, :integer
      add :settings, :map, default: %{}
      add :creator_id, :string, null: false
      add :winner_id, :string
      add :is_public, :boolean, default: true
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:tournaments, [:status])
    create index(:tournaments, [:format])
    create index(:tournaments, [:is_public])
    create index(:tournaments, [:creator_id])
    create index(:tournaments, [:start_time])
    create index(:tournaments, [:registration_deadline])
  end
end
