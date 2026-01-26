defmodule AnovaManager.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      # supervised GenServer that manages the Anova WebSocket connection
      AnovaManager.SousVide,

      # Simple Plug/Cowboy web UI to schedule jobs
      {Plug.Cowboy, scheme: :http, plug: AnovaManagerWeb.Router, options: [port: 4001]}
    ]

    opts = [strategy: :one_for_one, name: AnovaManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
