# 5songs

Party-Spiel: Songs aus **deiner Spotify-Playlist** laufen an, die Runde zieht eine von fünf Kategorien, und alle raten mit.

Live unter [5songs.com](https://5songs.com). Die öffentliche Instanz hängt an einer Spotify-Developer-App im Development-Modus: Spotify lässt dort nur eine kleine Allowlist hinterlegter Konten zu. **Zum Ausprobieren oder Mitspielen also selbst aufsetzen** (siehe unten).

## Die Idee

Klassiker wie [Hitsster](https://www.jumbo.eu/de/marken/hitsster) funktionieren so: Ein Song startet, alle raten Erscheinungsjahr (und oft mehr), wer näher dran ist, gewinnt die Karte. Die Karten sind fertig, du spielst immer denselben Pool.

5songs dreht das um: Statt Fertigkarten nimmst du **eure Playlists**. Familien-Mix, WG-Chronik, die 200er-Liste vom letzten Urlaub. Die Mechanik bleibt ein Ratespiel im Raum, der Katalog ist eurer.

Die App ist **kein** vollständiger digitaler Hitsster-Klon (keine Timeline, kein Bingo, keine Punktevergabe). Sie steuert Playback und Auflösung; gewertet wird am Tisch.

Nicht von Spotify oder Jumbo/Hitsster betrieben, keine offizielle Verbindung.

## Was die App kann

- **Spotify-Login** und Wiedergabe über die Web Playback SDK oder ein anderes Gerät (Handy, Speaker, Desktop-App).
- **Eigene Playlists** laden, eine auswählen, spielen. Gefolgte/fremde Playlists erscheinen ggf. in der Liste, lassen sich aber nicht abspielen. In Spotify in eine eigene Playlist kopieren.
- Pro Playlist bis zu **200 Songs**. Es zählen nur Tracks mit Titel, Interpret und Release-Jahr.
- **Fünf Kategorien**, im Wechsel (jede einmal, dann neu gemischt; nie dieselbe Kategorie zweimal hintereinander):
  - Genaues Erscheinungsjahr
  - Jahrzehnt
  - Erscheinungsjahr ±3
  - Interpret
  - Titel
- **Keine Wiederholungen** in einer Playlist, bis alle gültigen Songs durch sind.
- **Weiterspielen**: Spielstand (welche Songs schon liefen) bleibt im Browser.
- **Einstellungen**: Abspielgerät und Spieldauer (30 / 45 / 60 / 75 / 90 Sekunden).
- Beim Auflösen: Jahr, Titel, Interpret, Cover, Link zu Spotify, Link zum Gegenprüfen des Release-Jahrs.

Was sie bewusst nicht macht: Multiplayer-Räume, Highscores, fremde Playlists, kommerziellen Betrieb.

## So läuft eine Runde

1. Mit Spotify anmelden, Playlist wählen, Spiel starten.
2. **Nächste Runde:** eine Kategorie wird gezogen und angezeigt.
3. **Song abspielen:** kurzer Countdown, dann läuft der Track. Die Kategorie bleibt sichtbar, Titel und Interpret nicht.
4. Alle raten. **Stopp / Auflösen** oder der Timer beendet die Wiedergabe.
5. **Auflösen** zeigt Jahr, Titel und Interpret.
6. Nächste Runde, bis die Playlist durch ist.

Ein Gerät steuert, der Rest hört und rätselt. Spotify **Premium** ist für die Wiedergabe nötig.

## Voraussetzungen

- [Elixir](https://elixir-lang.org/install.html) 1.14+ (Entwicklung mit 1.18) **oder** Docker
- Spotify-Account mit **Premium**
- Eine [Spotify Developer App](https://developer.spotify.com/dashboard) (Client-ID + Secret)
- In der Developer App unter **User Management** dein Spotify-Konto (und ggf. Mitspieler-Konten) auf die Allowlist setzen, sonst schlägt der Login fehl

## Lokal starten

### 1. Spotify-App anlegen

1. App auf dem [Spotify Dashboard](https://developer.spotify.com/dashboard) erstellen.
2. **Redirect URI** eintragen (Spotify akzeptiert kein `localhost`, nur `127.0.0.1`):
   - Mix: `http://127.0.0.1:4000/auth/spotify/callback`
   - Docker: `http://127.0.0.1:4001/auth/spotify/callback`
3. Client-ID und Secret nach `.env` (Vorlage: `.env.example`).

### 2. Mit Elixir

```bash
mix setup
mix phx.server
```

Im Browser: [http://127.0.0.1:4000](http://127.0.0.1:4000). Mit IEx: `iex -S mix phx.server`.

### 3. Mit Docker

In `.env` zusätzlich `SECRET_KEY_BASE` setzen (`mix phx.gen.secret`).

```bash
docker compose up --build
```

App: [http://127.0.0.1:4001](http://127.0.0.1:4001).

## Fly.io (eigene Instanz)

Sinnvoll, wenn du 5songs dauerhaft für dich und die Allowlist-Konten hosten willst.

1. [flyctl](https://fly.io/docs/hands-on/install-flyctl) installieren, `fly auth login`
2. `fly launch --no-deploy`. App-Namen in `fly.toml` (`app`, `PHX_HOST`, `SPOTIFY_REDIRECT_URI`) anpassen
3. Secrets:

   ```bash
   fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)"
   fly secrets set SPOTIFY_CLIENT_ID="…"
   fly secrets set SPOTIFY_CLIENT_SECRET="…"
   ```

4. `fly deploy`
5. Redirect URI in der Spotify-Konsole: `https://<dein-host>/auth/spotify/callback`

## Technik

Phoenix LiveView, keine Datenbank: Session für Tokens, `localStorage` für den Spielstand. Spotify Web API + Web Playback SDK über [Exspotify](https://hex.pm/packages/exspotify). Hinweise zu API-Limits: [`docs/SPOTIFY_RATE_LIMIT.md`](docs/SPOTIFY_RATE_LIMIT.md).

```bash
mix test
```

## Rechtliches

Privater, nicht-kommerzieller Gebrauch. Spotify-Marken gehören der Spotify AB. Details: [Rechtliche Hinweise](https://5songs.com/rechtliches) auf der Live-Instanz bzw. `/rechtliches` lokal.
