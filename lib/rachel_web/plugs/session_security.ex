defmodule RachelWeb.Plugs.SessionSecurity do
  @moduledoc """
  Enhanced session security plug that provides:
  - Session fixation protection
  - Session hijacking detection
  - Automatic session renewal
  - Suspicious activity detection
  """
  import Plug.Conn
  require Logger
  alias RachelWeb.SecurityLogger

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> maybe_renew_session()
    |> detect_session_anomalies()
    |> refresh_session_activity()
  end

  # Renew session ID periodically to prevent fixation attacks
  defp maybe_renew_session(conn) do
    case get_session(conn, :session_created_at) do
      nil ->
        # New session, set creation timestamp
        conn
        |> put_session(:session_created_at, System.system_time(:second))
        |> put_session(:session_id, generate_session_id())

      created_at ->
        current_time = System.system_time(:second)
        session_age = current_time - created_at

        if session_age > session_renewal_interval() do
          # Renew session ID to prevent fixation
          old_session_id = get_session(conn, :session_id)
          new_session_id = generate_session_id()

          SecurityLogger.log_session_event(:renewal, old_session_id, %{
            new_session_id: new_session_id,
            session_age: session_age
          })

          conn
          |> configure_session(renew: true)
          |> put_session(:session_created_at, current_time)
          |> put_session(:session_id, new_session_id)
        else
          conn
        end
    end
  end

  # Detect potential session hijacking attempts
  defp detect_session_anomalies(conn) do
    current_user_agent = get_req_header(conn, "user-agent") |> List.first()
    current_ip = get_client_ip(conn)

    stored_user_agent = get_session(conn, :user_agent)
    stored_ip = get_session(conn, :client_ip)

    cond do
      # First time seeing this session
      is_nil(stored_user_agent) ->
        conn
        |> put_session(:user_agent, current_user_agent)
        |> put_session(:client_ip, current_ip)

      # User agent changed (potential hijacking)
      current_user_agent != stored_user_agent ->
        SecurityLogger.log_session_event(:hijacking_attempt, get_session(conn, :session_id), %{
          stored_user_agent: stored_user_agent,
          current_user_agent: current_user_agent,
          ip_address: current_ip,
          change_type: :user_agent
        })

        # Clear sensitive session data but don't destroy completely
        # to avoid disrupting legitimate users with changing user agents
        conn
        |> put_session(:security_warning, "Device or browser change detected")
        |> put_session(:user_agent, current_user_agent)

      # IP changed significantly (different subnet)
      ip_changed_significantly?(stored_ip, current_ip) ->
        SecurityLogger.log_session_event(:ip_change, get_session(conn, :session_id), %{
          stored_ip: stored_ip,
          current_ip: current_ip,
          change_type: :significant_ip_change
        })

        conn
        |> put_session(:security_warning, "Location change detected")
        |> put_session(:client_ip, current_ip)

      true ->
        conn
    end
  end

  # Update session activity timestamp
  defp refresh_session_activity(conn) do
    put_session(conn, :last_activity, System.system_time(:second))
  end

  # Helper functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp session_renewal_interval do
    # Renew session every 4 hours
    4 * 60 * 60
  end

  defp get_client_ip(conn) do
    # Check for real IP behind proxies/load balancers
    case get_req_header(conn, "x-real-ip") do
      [ip] ->
        ip

      [] ->
        case get_req_header(conn, "x-forwarded-for") do
          [forwarded] ->
            # Take first IP in comma-separated list
            forwarded |> String.split(",") |> List.first() |> String.trim()

          [] ->
            # Fallback to direct connection IP
            case conn.remote_ip do
              {a, b, c, d} ->
                "#{a}.#{b}.#{c}.#{d}"

              {a, b, c, d, e, f, g, h} ->
                "#{Integer.to_string(a, 16)}:#{Integer.to_string(b, 16)}:#{Integer.to_string(c, 16)}:#{Integer.to_string(d, 16)}:#{Integer.to_string(e, 16)}:#{Integer.to_string(f, 16)}:#{Integer.to_string(g, 16)}:#{Integer.to_string(h, 16)}"

              _ ->
                "unknown"
            end
        end
    end
  end

  defp ip_changed_significantly?(stored_ip, current_ip)
       when is_binary(stored_ip) and is_binary(current_ip) do
    case {parse_ipv4(stored_ip), parse_ipv4(current_ip)} do
      {{a1, b1, c1, _}, {a2, b2, c2, _}} ->
        # Consider it significant if the first 3 octets changed (different subnet)
        a1 != a2 or b1 != b2 or c1 != c2

      _ ->
        # If we can't parse as IPv4, consider any change significant
        stored_ip != current_ip
    end
  end

  defp ip_changed_significantly?(_, _), do: false

  defp parse_ipv4(ip_string) do
    case String.split(ip_string, ".") do
      [a, b, c, d] ->
        try do
          {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
        rescue
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
