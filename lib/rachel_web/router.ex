defmodule RachelWeb.Router do
  use RachelWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RachelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RachelWeb.Plugs.PlayerSession
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RachelWeb do
    pipe_through :browser

    get "/privacy", PageController, :privacy

    live_session :default,
      on_mount: [{RachelWeb.PlayerSessionHook, :default}] do
      live "/", HomeLive
      live "/play", GameLive, :create_with_ai
      live "/game/new", GameLive, :create_multiplayer
      live "/game/:game_id/lobby", GameLobbyLive
      live "/game/:game_id", GameLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", RachelWeb do
  #   pipe_through :api
  # end

  # LiveDashboard removed for simplicity
end
