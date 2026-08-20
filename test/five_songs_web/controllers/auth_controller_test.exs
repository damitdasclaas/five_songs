defmodule FiveSongsWeb.AuthControllerTest do
  use FiveSongsWeb.ConnCase, async: true

  test "HTML refresh without session redirects home", %{conn: conn} do
    conn = get(conn, ~p"/auth/spotify/refresh")
    assert redirected_to(conn) == ~p"/"
  end

  test "silent JSON refresh without session returns 401", %{conn: conn} do
    conn = get(conn, ~p"/auth/spotify/refresh?silent=1")
    assert json_response(conn, 401)["error"] == "not_logged_in"
  end
end
