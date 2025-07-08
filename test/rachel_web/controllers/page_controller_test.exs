defmodule RachelWeb.PageControllerTest do
  use RachelWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Rachel"
    assert response =~ "Quick Play"
    assert response =~ "Play vs AI"
    assert response =~ "Multiplayer"
  end
end
