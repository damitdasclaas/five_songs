defmodule FiveSongsWeb.AuthController do
  use FiveSongsWeb, :controller
  require Logger

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
    state = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    conn = put_session(conn, :spotify_state, state)

    conn =
      put_resp_cookie(conn, "spotify_oauth_state", state,
        max_age: 600,
        path: "/",
        same_site: "Lax",
        http_only: true,
        secure: conn.scheme == :https
      )

    {:ok, uri} =
      Exspotify.Auth.build_authorization_url(
        Exspotify.Auth.scopes_for_user_playback(),
        state
      )

    authorize_url = URI.to_string(uri)
    Logger.info("OAuth start: state=#{String.slice(state, 0, 8)}… host=#{conn.host} scheme=#{conn.scheme} url_has_state=#{String.contains?(authorize_url, "state=")}")
    redirect(conn, external: authorize_url)
  end

  def spotify_callback(conn, params) do
    conn = Plug.Conn.fetch_cookies(conn)

    url_state = params["state"]
    session_state = get_session(conn, :spotify_state)
    cookie_state = conn.req_cookies["spotify_oauth_state"]
    stored_state = session_state || cookie_state
    code = params["code"]
    error = params["error"]

    cookie_header = Plug.Conn.get_req_header(conn, "cookie") |> Enum.join("; ")
    has_session_cookie = String.contains?(cookie_header, "_five_songs_key")
    has_state_cookie = String.contains?(cookie_header, "spotify_oauth_state")

    Logger.warning("""
    OAuth callback debug:
      host=#{conn.host} scheme=#{conn.scheme}
      has_code=#{not is_nil(code)} has_url_state=#{not is_nil(url_state)} has_error=#{not is_nil(error)}
      session_state=#{inspect(session_state)}
      cookie_state=#{inspect(cookie_state)}
      url_state=#{inspect(url_state)}
      match=#{stored_state == url_state}
      has_session_cookie=#{has_session_cookie} has_state_cookie=#{has_state_cookie}
    """)

    cond do
      # Spotify-Fehler (z.B. Nutzer hat abgelehnt)
      is_binary(error) ->
        conn
        |> delete_session(:spotify_state)
        |> delete_resp_cookie("spotify_oauth_state", path: "/")
        |> put_flash(:error, if(error == "access_denied", do: "Anmeldung abgebrochen.", else: "Spotify-Fehler: #{error}."))
        |> redirect(to: ~p"/")

      # Kein Code von Spotify
      !is_binary(code) or code == "" ->
        conn
        |> put_flash(:error, "Kein Code von Spotify erhalten.")
        |> redirect(to: ~p"/")

      # Code vorhanden + State stimmt überein (Session oder Cookie)
      is_binary(url_state) and stored_state == url_state ->
        do_token_exchange(conn, code)

      # Code vorhanden + KEIN State in URL, aber State im Cookie/Session → akzeptieren
      is_nil(url_state) and not is_nil(stored_state) ->
        Logger.warning("OAuth: state missing from URL but found in cookie/session – accepting")
        do_token_exchange(conn, code)

      # State Mismatch oder kein gespeicherter State
      true ->
        message =
          cond do
            is_nil(stored_state) ->
              "Session verloren (kein State in Session oder Cookie). Bitte direkt https://5songs.com öffnen und erneut versuchen."
            stored_state != url_state ->
              "State stimmt nicht überein (CSRF-Schutz). Bitte erneut versuchen."
            true ->
              "Unbekannter Fehler bei der Anmeldung."
          end

        conn
        |> delete_resp_cookie("spotify_oauth_state", path: "/")
        |> put_flash(:error, message)
        |> redirect(to: ~p"/")
    end
  end

  defp do_token_exchange(conn, code) do
    conn = delete_session(conn, :spotify_state)
    conn = delete_resp_cookie(conn, "spotify_oauth_state", path: "/")

    case Exspotify.Auth.exchange_code_for_token(code) do
      {:ok, %{"access_token" => access_token, "refresh_token" => refresh_token}} ->
        Logger.info("OAuth: token exchange successful")
        conn
        |> put_session(:spotify_access_token, access_token)
        |> put_session(:spotify_refresh_token, refresh_token)
        |> redirect(to: ~p"/")

      {:error, reason} ->
        Logger.warning("OAuth: token exchange failed: #{inspect(reason)}")
        conn
        |> put_flash(:error, "Spotify Login fehlgeschlagen: #{inspect(reason)}")
        |> redirect(to: ~p"/")
    end
  end
end
