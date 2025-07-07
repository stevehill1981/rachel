defmodule RachelWeb.Plugs.RateLimit do
  @moduledoc """
  Plug for rate limiting requests.
  Can be configured per-pipeline or per-route.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, 60),
      window_ms: Keyword.get(opts, :window_ms, :timer.seconds(60)),
      key_func: Keyword.get(opts, :key_func, :default_key),
      error_response: Keyword.get(opts, :error_response, :default_error)
    }
  end

  def call(conn, %{
        max_requests: max_requests,
        window_ms: window_ms,
        key_func: key_func,
        error_response: error_response
      }) do
    key = apply_key_func(conn, key_func)

    case Rachel.RateLimiter.check_rate(key, max_requests: max_requests, window_ms: window_ms) do
      {:ok, remaining} ->
        # Add rate limit headers
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(max_requests))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        |> put_resp_header("x-ratelimit-reset", to_string(reset_time(window_ms)))

      {:error, :rate_limited} ->
        # Rate limited - return error response
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("x-ratelimit-limit", to_string(max_requests))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_resp_header("x-ratelimit-reset", to_string(reset_time(window_ms)))
        |> put_resp_header("retry-after", to_string(div(window_ms, 1000)))
        |> apply_error_response(error_response)
        |> halt()
    end
  end

  defp apply_key_func(conn, :default_key), do: default_key(conn)
  defp apply_key_func(conn, func) when is_function(func, 1), do: func.(conn)

  defp apply_error_response(conn, :default_error), do: default_error_response(conn)
  defp apply_error_response(conn, func) when is_function(func, 1), do: func.(conn)

  # Default key function - uses IP address
  defp default_key(conn) do
    ip = get_ip(conn)
    "ip:#{ip}"
  end

  # Get real IP address, checking X-Forwarded-For header
  defp get_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips | _] ->
        # Take the first IP from the comma-separated list
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fall back to remote_ip
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  # Calculate reset time (current time + window)
  defp reset_time(window_ms) do
    System.system_time(:second) + div(window_ms, 1000)
  end

  # Default error response
  defp default_error_response(conn) do
    json(conn, %{
      error: "Rate limit exceeded",
      message: "Too many requests. Please try again later."
    })
  end
end
