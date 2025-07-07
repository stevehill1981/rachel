defmodule RachelWeb.PageControllerTest do
  use RachelWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Rachel"
    assert response =~ "Play Instantly"
    assert response =~ "Play with Friends"
  end
end
