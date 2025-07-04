defmodule Rachel.Accounts.PlayerProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Rachel.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_profiles" do
    field :player_id, :string
    field :display_name, :string
    
    # Aggregate stats
    field :total_games_played, :integer, default: 0
    field :total_games_won, :integer, default: 0
    field :total_score, :integer, default: 0
    field :average_score, :float, default: 0.0
    field :win_rate, :float, default: 0.0
    field :total_cards_played, :integer, default: 0
    field :total_cards_drawn, :integer, default: 0
    field :total_special_cards_played, :integer, default: 0
    field :quickest_win_turns, :integer
    field :longest_game_turns, :integer, default: 0
    field :favorite_special_card, :string
    field :current_streak, :integer, default: 0
    field :best_streak, :integer, default: 0
    field :last_played_at, :utc_datetime
    field :rank, :integer

    belongs_to :user, User, foreign_key: :user_id, type: :id

    timestamps()
  end

  @doc false
  def changeset(player_profile, attrs) do
    player_profile
    |> cast(attrs, [
      :player_id, :display_name, :total_games_played, :total_games_won,
      :total_score, :average_score, :win_rate, :total_cards_played,
      :total_cards_drawn, :total_special_cards_played, :quickest_win_turns,
      :longest_game_turns, :favorite_special_card, :current_streak,
      :best_streak, :last_played_at, :rank, :user_id
    ])
    |> validate_required([:player_id, :display_name])
    |> unique_constraint(:player_id)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  def calculate_derived_stats(changeset) do
    case {get_field(changeset, :total_games_played), get_field(changeset, :total_games_won), get_field(changeset, :total_score)} do
      {games, wins, score} when is_integer(games) and games > 0 ->
        changeset
        |> put_change(:win_rate, wins / games * 100)
        |> put_change(:average_score, score / games)
      _ ->
        changeset
    end
  end
end