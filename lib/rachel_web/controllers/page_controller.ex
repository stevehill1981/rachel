defmodule RachelWeb.PageController do
  use RachelWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end
end
