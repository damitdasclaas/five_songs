defmodule FiveSongsWeb.PageController do
  use FiveSongsWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end

  def impressum(conn, _params) do
    render(conn, :impressum)
  end

  def rechtliches(conn, _params) do
    render(conn, :rechtliches)
  end
end
