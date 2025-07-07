defmodule RachelWeb.HealthControllerTest do
  use RachelWeb.ConnCase, async: true

  test "GET /health returns ok", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /health/deep returns detailed status", %{conn: conn} do
    conn = get(conn, "/health/deep")
    response = json_response(conn, 200)
    
    assert response["status"] == "ok"
    assert is_map(response["checks"])
    assert Map.has_key?(response["checks"], "database")
    assert Map.has_key?(response["checks"], "memory")
  end
end