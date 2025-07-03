defmodule RachelWeb.Plugs.PlayerSession do
  @moduledoc """
  Plug to manage player session data.
  Ensures each player has a persistent ID and name across sessions.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    player_id = get_session(conn, :player_id) || generate_player_id()
    player_name = get_session(conn, :player_name) || generate_player_name()
    
    conn
    |> put_session(:player_id, player_id)
    |> put_session(:player_name, player_name)
    |> assign(:player_id, player_id)
    |> assign(:player_name, player_name)
  end
  
  defp generate_player_id do
    "player_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp generate_player_name do
    # Generate a fun random name
    adjectives = [
      "Clever", "Swift", "Brave", "Wise", "Sharp", "Quick", "Bold", "Keen",
      "Bright", "Calm", "Cool", "Daring", "Eager", "Fair", "Gentle", "Happy",
      "Jolly", "Kind", "Lively", "Merry", "Noble", "Proud", "Quiet", "Ready"
    ]
    
    animals = [
      "Wolf", "Bear", "Eagle", "Lion", "Tiger", "Hawk", "Falcon", "Dragon",
      "Phoenix", "Raven", "Fox", "Lynx", "Puma", "Jaguar", "Leopard", "Panther",
      "Otter", "Badger", "Owl", "Crane", "Heron", "Swan", "Dove", "Sparrow"
    ]
    
    "#{Enum.random(adjectives)}#{Enum.random(animals)}"
  end
end