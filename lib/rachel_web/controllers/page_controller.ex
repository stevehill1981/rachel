defmodule RachelWeb.PageController do
  use RachelWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
