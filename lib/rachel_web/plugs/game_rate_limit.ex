defmodule RachelWeb.Plugs.GameRateLimit do
  @moduledoc """
  Specialized rate limiting for game-related actions.
  More restrictive than general API rate limiting.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    # Use player_id if available, otherwise IP
    key = case conn.assigns[:player_id] do
      nil -> "game:ip:#{get_ip(conn)}"
      player_id -> "game:player:#{player_id}"
    end
    
    # Allow 10 games per 5 minutes
    case Rachel.RateLimiter.check_rate(key, max_requests: 10, window_ms: :timer.minutes(5)) do
      {:ok, _remaining} ->
        conn
        
      {:error, :rate_limited} ->
        # For browser requests, redirect with flash
        if get_format(conn) == "html" do
          conn
          |> put_flash(:error, "You're creating games too quickly. Please wait a few minutes.")
          |> redirect(to: "/lobby")
          |> halt()
        else
          # For API/LiveView, return error
          conn
          |> put_status(:too_many_requests)
          |> json(%{error: "Too many games created. Please wait before creating another."})
          |> halt()
        end
    end
  end
  
  defp get_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips | _] ->
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()
      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
  
  defp get_format(conn) do
    case get_req_header(conn, "accept") do
      ["application/json" <> _ | _] -> "json"
      _ -> "html"
    end
  end
  
  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end
end