defmodule BedrockServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Logger.configure(
      level: case (System.fetch_env("LOG_LEVEL")) do
        {:ok, "debug"} -> :debug
        {:ok, "info"} -> :info
        {:ok, "warn"} -> :warn
        {:ok, "error"} -> :error
        _ -> :debug
      end
    )

    opts = [strategy: :one_for_one, name: BedrockServer.Supervisor]

    Supervisor.start_link([
      {RakNet.Server, %{
        guid: 13547959620129336354,
        host: {127, 0, 0, 1},
        port: 19132,
        portv6: 19133,
        client_module: BedrockServer.Client.State,
        client_data: %{},
      }},
      #{BedrockServer.SessionServer, %{}},
      {Registry, keys: :unique, name: BedrockServer.Client},
    ], opts)
  end
end
