defmodule RachelWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Plug for adding comprehensive security headers including Content Security Policy.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_csp_header()
    |> put_additional_security_headers()
  end

  defp put_csp_header(conn) do
    # Get nonce for inline scripts if available
    nonce = get_csp_nonce(conn)

    csp_policy = build_csp_policy(nonce)

    put_resp_header(conn, "content-security-policy", csp_policy)
  end

  defp build_csp_policy(nonce) do
    nonce_directive = if nonce, do: " 'nonce-#{nonce}'", else: ""

    [
      "default-src 'self'",
      # unsafe-eval needed for LiveView
      "script-src 'self' 'unsafe-eval'#{nonce_directive}",
      # unsafe-inline needed for Tailwind
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self' data:",
      # WebSocket connections for LiveView
      "connect-src 'self' ws: wss:",
      "frame-ancestors 'none'",
      "form-action 'self'",
      "base-uri 'self'",
      "object-src 'none'",
      "media-src 'self'"
    ]
    |> Enum.join("; ")
  end

  defp get_csp_nonce(conn) do
    # Try to get nonce from assigns (if set by another plug)
    case conn.assigns[:csp_nonce] do
      nil -> generate_nonce()
      nonce -> nonce
    end
  end

  defp generate_nonce do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> binary_part(0, 16)
  end

  defp put_additional_security_headers(conn) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    # HSTS header - only in production with HTTPS
    |> maybe_put_hsts_header()
  end

  defp maybe_put_hsts_header(conn) do
    # In production, HSTS is handled by Fly.io or the endpoint force_ssl config
    # We check if the connection is using HTTPS
    if conn.scheme == :https do
      put_resp_header(
        conn,
        "strict-transport-security",
        "max-age=31536000; includeSubDomains; preload"
      )
    else
      conn
    end
  end
end
