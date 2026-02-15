defmodule FiveSongsWeb.SettingsController do
  use FiveSongsWeb, :controller

  @duration_options [30, 45, 60, 75, 90]

  def set_device(conn, %{"id" => id}) when is_binary(id) and id != "" do
    if logged_in?(conn) do
      conn
      |> put_session(:spotify_device_id, id)
      |> put_flash(:info, "Abspielgerät gespeichert.")
      |> redirect(to: ~p"/settings")
    else
      redirect(conn, to: ~p"/")
    end
  end

  def set_device(conn, _), do: redirect(conn, to: ~p"/settings")

  def set_duration(conn, %{"sec" => sec}) do
    if logged_in?(conn) do
      sec = sec |> String.to_integer() |> then(&if(&1 in @duration_options, do: &1, else: 60))
      conn
      |> put_session(:play_duration_sec, sec)
      |> put_flash(:info, "Spieldauer gespeichert.")
      |> redirect(to: ~p"/settings")
    else
      redirect(conn, to: ~p"/")
    end
  end

  def set_duration(conn, _), do: redirect(conn, to: ~p"/settings")

  defp logged_in?(conn), do: get_session(conn, :spotify_access_token) != nil
end
