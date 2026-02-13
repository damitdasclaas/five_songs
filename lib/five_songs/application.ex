defmodule FiveSongs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FiveSongsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:five_songs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FiveSongs.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FiveSongs.Finch},
      # Start a worker by calling: FiveSongs.Worker.start_link(arg)
      # {FiveSongs.Worker, arg},
      # Start to serve requests, typically the last entry
      FiveSongsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FiveSongs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FiveSongsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
