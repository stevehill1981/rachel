defmodule Rachel.Repo.Migrations.CreatePlayerStats do
  use Ecto.Migration

  def change do
    create table(:player_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: true
      add :player_id, :string, null: false
      add :player_name, :string, null: false
      add :game_record_id, references(:game_records, type: :binary_id, on_delete: :delete_all), null: false
      
      # Game-specific stats
      add :finish_position, :integer
      add :cards_played, :integer, null: false, default: 0
      add :cards_drawn, :integer, null: false, default: 0
      add :special_cards_played, :integer, null: false, default: 0
      add :won, :boolean, null: false, default: false
      add :score, :integer, null: false, default: 0
      
      timestamps()
    end

    create index(:player_stats, [:user_id])
    create index(:player_stats, [:player_id])
    create index(:player_stats, [:game_record_id])
    create index(:player_stats, [:won])
    create index(:player_stats, [:score])
    create index(:player_stats, [:finish_position])
    
    # Composite index for leaderboards
    create index(:player_stats, [:score, :won])
  end
end
