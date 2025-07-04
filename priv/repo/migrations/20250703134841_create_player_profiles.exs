defmodule Rachel.Repo.Migrations.CreatePlayerProfiles do
  use Ecto.Migration

  def change do
    create table(:player_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: true
      add :player_id, :string, null: false
      add :display_name, :string, null: false
      
      # Aggregate stats
      add :total_games_played, :integer, null: false, default: 0
      add :total_games_won, :integer, null: false, default: 0
      add :total_score, :integer, null: false, default: 0
      add :average_score, :float, null: false, default: 0.0
      add :win_rate, :float, null: false, default: 0.0
      add :total_cards_played, :integer, null: false, default: 0
      add :total_cards_drawn, :integer, null: false, default: 0
      add :total_special_cards_played, :integer, null: false, default: 0
      add :quickest_win_turns, :integer
      add :longest_game_turns, :integer, null: false, default: 0
      add :favorite_special_card, :string
      add :current_streak, :integer, null: false, default: 0
      add :best_streak, :integer, null: false, default: 0
      add :last_played_at, :utc_datetime
      add :rank, :integer
      
      timestamps()
    end

    create unique_index(:player_profiles, [:user_id])
    create unique_index(:player_profiles, [:player_id])
    create index(:player_profiles, [:total_score])
    create index(:player_profiles, [:win_rate])
    create index(:player_profiles, [:total_games_won])
    create index(:player_profiles, [:rank])
    create index(:player_profiles, [:last_played_at])
  end
end
