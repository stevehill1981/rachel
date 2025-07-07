defmodule RachelWeb.Plugs.BasicAuthTest do
  use RachelWeb.ConnCase, async: true
  
  alias RachelWeb.Plugs.BasicAuth

  test "allows access with correct credentials" do
    # Create basic auth header  
    credentials = Base.encode64("admin:rachel_admin_2024")
    
    conn = 
      build_conn()
      |> put_req_header("authorization", "Basic #{credentials}")
      |> BasicAuth.call([])
    
    refute conn.halted
  end

  test "denies access without authorization header" do
    conn = 
      build_conn()
      |> BasicAuth.call([])
    
    assert conn.halted
    assert conn.status == 401
  end

  test "denies access with incorrect credentials" do
    credentials = Base.encode64("wrong:password")
    
    conn = 
      build_conn()
      |> put_req_header("authorization", "Basic #{credentials}")
      |> BasicAuth.call([])
    
    assert conn.halted
    assert conn.status == 401
  end

  test "denies access with malformed authorization header" do
    conn = 
      build_conn()
      |> put_req_header("authorization", "Bearer token123")
      |> BasicAuth.call([])
    
    assert conn.halted
    assert conn.status == 401
  end
end