# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :five_songs,
  generators: [timestamp_type: :utc_datetime]
# Optional: config :five_songs, play_duration_sec: 90  # default 60

# Configures the endpoint
config :five_songs, FiveSongsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FiveSongsWeb.ErrorHTML, json: FiveSongsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FiveSongs.PubSub,
  live_view: [signing_salt: "e98Ofdo9"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :five_songs, FiveSongs.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  five_songs: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  five_songs: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Tesla (used by Exspotify’s OAuth dependency) soft-deprecation; recommended by library
config :tesla, disable_deprecated_builder_warning: true

# Exspotify: user auth only (no TokenManager)
config :exspotify,
  token_manager: false,
  redirect_uri: "http://localhost:4000/auth/spotify/callback"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
