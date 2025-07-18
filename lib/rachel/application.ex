defmodule Rachel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DNSCluster, query: Application.get_env(:rachel, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Rachel.PubSub},
      # Game Registry for tracking active games
      {Registry, keys: :unique, name: Rachel.GameRegistry},
      # Dynamic supervisor for game servers
      {DynamicSupervisor, name: Rachel.GameSupervisor, strategy: :one_for_one},
      # Start to serve requests, typically the last entry
      RachelWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rachel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RachelWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
