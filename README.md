# FiveSongs

## Starten (lokal)

1. **Dependencies:** `mix setup` (einmalig)
2. **Server starten:** `mix phx.server` oder mit IEx: `iex -S mix phx.server`
3. Im Browser: [localhost:4000](http://localhost:4000)

Spotify-Credentials kommen aus `.env` (siehe `.env.example`).

### Docker

Build and run with Docker (production release):

```bash
# Build
docker build -t five_songs .

# Run (set required env vars; generate SECRET_KEY_BASE with: mix phx.gen.secret)
docker run --rm -p 4000:4000 \
  -e SECRET_KEY_BASE=your-secret-key-base \
  -e SPOTIFY_CLIENT_ID=... \
  -e SPOTIFY_CLIENT_SECRET=... \
  -e PHX_HOST=localhost \
  five_songs
```

Required env vars: `SECRET_KEY_BASE`, `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`. Optional: `PORT` (default 4000), `PHX_HOST`, `SPOTIFY_REDIRECT_URI` (e.g. `https://yourdomain.com/auth/spotify/callback`), `DNS_CLUSTER_QUERY`.

### Fly.io (Deploy)

1. **CLI installieren:** [fly.io/docs/hands-on/install-flyctl](https://fly.io/docs/hands-on/install-flyctl)  
2. **Anmelden:** `fly auth login`  
3. **App erstellen & deployen:**  
   ```bash
   fly launch --no-deploy
   ```  
   Wenn du den App-Namen änderst, in `fly.toml` `app` sowie `PHX_HOST` und `SPOTIFY_REDIRECT_URI` anpassen.  
4. **Secrets setzen:**  
   ```bash
   fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)"
   fly secrets set SPOTIFY_CLIENT_ID="deine-client-id"
   fly secrets set SPOTIFY_CLIENT_SECRET="dein-client-secret"
   ```  
5. **Deploy:**  
   ```bash
   fly deploy
   ```  
6. **Spotify:** In der [Spotify Developer Console](https://developer.spotify.com/dashboard) bei deiner App unter "Redirect URIs" eintragen:  
   `https://<dein-app-name>.fly.dev/auth/spotify/callback`

Danach: `https://<dein-app-name>.fly.dev`

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
