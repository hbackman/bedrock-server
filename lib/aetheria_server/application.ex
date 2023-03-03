defmodule AetheriaServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: AetheriaServer.Supervisor]

    Supervisor.start_link([
      {AetheriaServer, 2052},
    ], opts)
  end
end