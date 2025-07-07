defmodule RachelWeb.HealthController do
  use RachelWeb, :controller
  
  @doc """
  Basic health check endpoint.
  Returns 200 OK if the application is running.
  """
  def check(conn, _params) do
    json(conn, %{
      status: "ok",
      service: "rachel",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
  
  @doc """
  Detailed health check that verifies database connectivity and other services.
  Used for more thorough monitoring.
  """
  def detailed(conn, _params) do
    checks = %{
      database: check_database(),
      game_servers: check_game_servers(),
      memory: check_memory_usage()
    }
    
    overall_status = if all_healthy?(checks), do: "healthy", else: "degraded"
    status_code = if all_healthy?(checks), do: 200, else: 503
    
    conn
    |> put_status(status_code)
    |> json(%{
      status: overall_status,
      service: "rachel",
      version: Application.spec(:rachel, :vsn) |> to_string(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: checks,
      node: node() |> to_string()
    })
  end
  
  defp check_database do
    try do
      # Simple query to verify database connectivity
      Rachel.Repo.query!("SELECT 1")
      %{status: "healthy", message: "Database connection OK"}
    rescue
      _ -> %{status: "unhealthy", message: "Database connection failed"}
    end
  end
  
  defp check_game_servers do
    # Count active game servers
    game_count = Registry.count(Rachel.GameRegistry)
    
    %{
      status: "healthy",
      message: "Game servers operational",
      active_games: game_count
    }
  end
  
  defp check_memory_usage do
    # Get memory usage in MB
    memory_mb = :erlang.memory(:total) / 1_048_576
    
    status = if memory_mb < 1500, do: "healthy", else: "warning"
    
    %{
      status: status,
      message: "Memory usage: #{Float.round(memory_mb, 2)} MB",
      memory_mb: Float.round(memory_mb, 2)
    }
  end
  
  defp all_healthy?(checks) do
    Enum.all?(checks, fn {_key, check} ->
      check[:status] == "healthy"
    end)
  end
end