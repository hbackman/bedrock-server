defmodule BedrockServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: BedrockServer.Supervisor]

    Supervisor.start_link([
      {BedrockServer, 19132},
      {Registry, keys: :unique, name: RakNet.Connection},
    ], opts)
  end
end
