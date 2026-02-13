defmodule FiveSongsWeb.AuthController do
  use FiveSongsWeb, :controller

  def refresh(conn, _params) do
    case get_session(conn, :spotify_refresh_token) do
      nil ->
        conn
        |> put_flash(:error, "Nicht angemeldet.")
        |> redirect(to: ~p"/")

      refresh_token ->
        case Exspotify.Auth.refresh_access_token(refresh_token) do
          {:ok, %{"access_token" => access_token} = body} ->
            conn
            |> put_session(:spotify_access_token, access_token)
            |> maybe_put_refresh_token(body)
            |> put_flash(:info, "Token erneuert. Bitte Playlist erneut wählen.")
            |> redirect(to: ~p"/")

          {:error, _} ->
            conn
            |> put_flash(:error, "Token konnte nicht erneuert werden. Bitte erneut anmelden.")
            |> redirect(to: ~p"/auth/logout")
        end
    end
  end

  defp maybe_put_refresh_token(conn, %{"refresh_token" => rt}), do: put_session(conn, :spotify_refresh_token, rt)
  defp maybe_put_refresh_token(conn, _), do: conn

  def logout(conn, _params) do
    conn
    |> delete_session(:spotify_access_token)
    |> delete_session(:spotify_refresh_token)
    |> delete_session(:spotify_state)
    |> put_flash(:info, "Abgemeldet.")
    |> redirect(to: ~p"/")
  end

  # Session löschen und sofort zu Spotify-Anmeldung – für einen komplett neuen Token (z. B. nach User Management / Scopes).
  def reauth(conn, _params) do
    conn
    |> delete_session(:spotify_access_token)
    |> delete_session(:spotify_refresh_token)
    |> delete_session(:spotify_state)
    |> put_flash(:info, "Bitte erneut bei Spotify anmelden.")
    |> redirect(to: ~p"/auth/spotify")
  end

  def spotify(conn, _params) do
    state = Base.encode64(:crypto.strong_rand_bytes(16))
    conn = put_session(conn, :spotify_state, state)

    {:ok, uri} =
      Exspotify.Auth.build_authorization_url(
        Exspotify.Auth.scopes_for_user_playback(),
        state
      )

    redirect(conn, external: URI.to_string(uri))
  end

  def spotify_callback(conn, %{"code" => code, "state" => state}) do
    if get_session(conn, :spotify_state) != state do
      conn
      |> put_flash(:error, "Invalid state. Please try again.")
      |> redirect(to: ~p"/")
    else
      conn = delete_session(conn, :spotify_state)

      case Exspotify.Auth.exchange_code_for_token(code) do
        {:ok, %{"access_token" => access_token, "refresh_token" => refresh_token}} ->
          conn
          |> put_session(:spotify_access_token, access_token)
          |> put_session(:spotify_refresh_token, refresh_token)
          |> redirect(to: ~p"/")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "Spotify login failed. Please try again.")
          |> redirect(to: ~p"/")
      end
    end
  end

  def spotify_callback(conn, _params) do
    conn
    |> put_flash(:error, "Missing code from Spotify.")
    |> redirect(to: ~p"/")
  end
end
