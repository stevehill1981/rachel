defmodule RachelWeb.PlayerSessionHook do
  @moduledoc """
  LiveView hook to ensure player session data is available in LiveView mount.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    # Get player data from session, creating if necessary
    player_id = session["player_id"] || session[:player_id] || generate_player_id()
    player_name = session["player_name"] || session[:player_name] || generate_player_name()

    socket =
      socket
      |> assign(:player_id, player_id)
      |> assign(:player_name, player_name)
      # Keep track of the session player_id
      |> assign(:session_player_id, player_id)
      |> assign(:session_player_name, player_name)

    # Ensure the session data is set for future requests
    {:cont, socket}
  end

  defp generate_player_id do
    "player_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp generate_player_name do
    adjectives = ["Happy", "Clever", "Lucky", "Swift", "Bright", "Cheerful", "Bold", "Wise"]
    nouns = ["Player", "Gamer", "Friend", "Explorer", "Hero", "Champion", "Ace", "Star"]

    adjective = Enum.random(adjectives)
    noun = Enum.random(nouns)

    "#{adjective} #{noun}"
  end
end
