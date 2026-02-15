defmodule FiveSongsWeb.SettingsController do
  use FiveSongsWeb, :controller

  @duration_options [30, 45, 60, 75, 90]

  def set_device(conn, %{"id" => id}) when is_binary(id) and id != "" do
    if logged_in?(conn) do
      conn
      |> put_session(:spotify_device_id, id)
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
      |> redirect(to: ~p"/settings")
    else
      redirect(conn, to: ~p"/")
    end
  end

  def set_duration(conn, _), do: redirect(conn, to: ~p"/settings")

  def refresh_devices(conn, _params) do
    if token = get_session(conn, :spotify_access_token) do
      case Exspotify.Player.get_available_devices(token) do
        {:ok, %{devices: devices}} ->
          cache = Enum.map(devices || [], &device_to_cache/1)
          conn
          |> put_session(:cached_devices, cache)
          |> put_session(:cached_devices_at, System.system_time(:second))
          |> put_flash(:info, "Geräteliste aktualisiert.")
          |> redirect(to: ~p"/settings")

        {:error, %Exspotify.Error{type: :unauthorized}} ->
          redirect(conn, to: ~p"/auth/spotify/reauth")

        _ ->
          conn
          |> put_session(:cached_devices, [])
          |> put_flash(:error, "Geräte konnten nicht geladen werden.")
          |> redirect(to: ~p"/settings")
      end
    else
      redirect(conn, to: ~p"/")
    end
  end

  defp device_to_cache(%{id: id, name: name, type: type}) do
    %{"id" => id, "name" => name, "type" => type}
  end

  defp logged_in?(conn), do: get_session(conn, :spotify_access_token) != nil
end
