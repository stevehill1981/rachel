defmodule RachelWeb.Plugs.BasicAuth do
  @moduledoc """
  Basic HTTP authentication for admin routes.
  """
  
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    username = System.get_env("ADMIN_USERNAME", "admin")
    password = System.get_env("ADMIN_PASSWORD", "rachel_admin_2024")
    
    case get_req_header(conn, "authorization") do
      ["Basic " <> auth] ->
        case Base.decode64(auth) do
          {:ok, credentials} ->
            if credentials == "#{username}:#{password}" do
              conn
            else
              unauthorized(conn)
            end
          _ ->
            unauthorized(conn)
        end
      _ ->
        unauthorized(conn)
    end
  end
  
  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"Admin Area\"")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end