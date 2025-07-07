defmodule RachelWeb.AdminDashboardLiveTest do
  use RachelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders admin dashboard with basic auth", %{conn: conn} do
    # Add basic auth header
    credentials = Base.encode64("admin:rachel_admin_2024")
    
    conn = 
      conn
      |> put_req_header("authorization", "Basic #{credentials}")
    
    {:ok, _view, html} = live(conn, "/admin")
    
    assert html =~ "Admin Dashboard"
    assert html =~ "System Status"
  end

  test "requires authentication for admin dashboard", %{conn: conn} do
    # Should redirect to unauthorized without auth
    assert {:error, {:redirect, %{to: _}}} = live(conn, "/admin")
  end
end