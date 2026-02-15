# FiveSongs

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

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

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
