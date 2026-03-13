defmodule Pigeon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PigeonWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:pigeon, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pigeon.PubSub},
      # Start a worker by calling: Pigeon.Worker.start_link(arg)
      # {Pigeon.Worker, arg},
      # Start to serve requests, typically the last entry
      Pigeon.Presence,
      PigeonWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pigeon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PigeonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
