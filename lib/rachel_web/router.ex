defmodule RachelWeb.Router do
  use RachelWeb, :router

  import RachelWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RachelWeb.Plugs.SessionSecurity
    plug :fetch_live_flash
    plug :put_root_layout, html: {RachelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RachelWeb.Plugs.SecurityHeaders
    plug :fetch_current_scope_for_user
    plug RachelWeb.Plugs.PlayerSession
  end

  pipeline :api do
    plug :accepts, ["json"]
    # Rate limit API endpoints: 300 requests per minute
    plug RachelWeb.Plugs.RateLimit, max_requests: 300, window_ms: 60_000
  end
  
  pipeline :admin do
    plug :browser
    plug RachelWeb.Plugs.BasicAuth
  end

  scope "/", RachelWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :default,
      on_mount: [{RachelWeb.PlayerSessionHook, :default}] do
      live "/lobby", LobbyLive
      live "/practice", PracticeLive
      live "/play", InstantPlayLive
      live "/game", GameLive
      live "/game/:game_id", GameLive
    end
  end

  # Health check endpoints (no authentication required)
  scope "/health", RachelWeb do
    pipe_through :api
    
    get "/", HealthController, :check
    get "/detailed", HealthController, :detailed
  end
  
  # Admin routes (protected by basic auth)
  scope "/admin", RachelWeb do
    pipe_through :admin
    
    live "/", AdminDashboardLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", RachelWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rachel, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RachelWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", RachelWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", RachelWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", RachelWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
