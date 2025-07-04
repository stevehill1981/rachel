defmodule Rachel.Accounts.PlayerStats do
  use Ecto.Schema
  import Ecto.Changeset

  alias Rachel.Accounts.{User, GameRecord}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_stats" do
    field :player_id, :string
    field :player_name, :string
    field :finish_position, :integer
    field :cards_played, :integer, default: 0
    field :cards_drawn, :integer, default: 0
    field :special_cards_played, :integer, default: 0
    field :won, :boolean, default: false
    field :score, :integer, default: 0

    belongs_to :user, User, foreign_key: :user_id, type: :id
    belongs_to :game_record, GameRecord

    timestamps()
  end

  @doc false
  def changeset(player_stats, attrs) do
    player_stats
    |> cast(attrs, [
      :player_id,
      :player_name,
      :finish_position,
      :cards_played,
      :cards_drawn,
      :special_cards_played,
      :won,
      :score,
      :user_id,
      :game_record_id
    ])
    |> validate_required([:player_id, :player_name, :game_record_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:game_record_id)
  end
end
