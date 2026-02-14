# Spotify API – wo wir Requests machen und wie du sie reduzierst

Spotify begrenzt die Anzahl der API-Aufrufe. Wenn du zu oft an die Grenze kommst, hilft es zu wissen, wo überall Requests anfallen und wie man sie reduziert.

## Wo wir Requests machen

| Aktion | Requests | Details |
|--------|----------|--------|
| **„Playlists laden“ klicken** (oder Aktualisieren) | **2** | `get_current_user_profile` + `get_current_users_playlists` (limit 50). Kein automatischer Request beim Öffnen. |
| **Playlist anklicken** (Tracks laden) | **1–4** | `get_playlist_items` pro 50 Tracks, **max. 200 Tracks** = 4 Requests |
| **„Nochmal versuchen“** (Playlists) | **2** | wie Playlist-Bildschirm |
| **„Nochmal versuchen“** (Tracks) | **1–4** | wie Playlist anklicken |
| **Token erneuern** (`/auth/spotify/refresh`) | **1** | Spotify Token-Endpoint (nicht Web-API, aber zählt) |

**Keine** Spotify-Web-API-Requests: Countdown, Timer, „Nächster Song“ (Track ist schon geladen), Reveal. Playback steuern wir über die **Web Playback SDK** (PUT `me/player/play`) – das ist ein anderes Kontingent als die Web-API.

## Was wir schon tun

- **Eigene Playlists nur**: `get_current_users_playlists` + Filter nach Owner → wir rufen keine weiteren Playlist-Details pro Playlist ab.
- **Pagination-Cap**: Nur **200 Tracks** pro Playlist laden (nicht 500), also max. 4× `get_playlist_items` pro Playlist.
- **Kein Polling**: Kein periodisches Abfragen von Playback-State über die Web-API; der Timer startet nach Client-Event `playback_started`.

## Wie du weiter sparen kannst

1. **Max. Tracks pro Playlist senken**  
   In `game_live.ex`: `fetch_all_playlist_items(..., max_items \\ 200)` auf z.B. `100` oder `150` setzen → weniger Requests pro Playlist (2–3 statt 4).

2. **Playlists nur bei Bedarf laden**  
   Playlists werden **nicht** automatisch beim Öffnen geladen. Es gibt einen Button „Playlists laden“ und ein Aktualisieren-Icon – nur dann werden die 2 Requests ausgelöst.

3. **„Nochmal versuchen“ sparsam nutzen**  
   Jeder Klick = erneut 2 (Playlists) bzw. 1–4 (Tracks) Requests. Nur bei echten Fehlern nutzen.

4. **Token-Refresh**  
   Pro Refresh 1 Request; sinnvoll nur bei Ablauf. Den 45-Min-Proaktiv-Refresh haben wir drin – das verhindert viele 401 und damit doppelte Versuche.

5. **Development / Tests**  
   Häufiges Neuladen der App oder Wechseln zwischen Playlists in kurzer Zeit = viele Requests. In der Produktion mit echten Nutzern ist die Last meist geringer.

## Grenzen (Spotify)

- Web-API: eigene Limits pro Endpoint (z.B. 180 Requests / 15 min für viele Endpoints).  
- Bei 429 (Too Many Requests): Response-Header `Retry-After` beachten; Backoff einhalten.

Wenn du genau wissen willst, welcher Endpoint wie oft aufgerufen wird, kannst du in Exspotify temporär `config :exspotify, debug: true` setzen – dann werden Requests geloggt.
