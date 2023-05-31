defmodule BedrockServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: BedrockServer.Supervisor]

    Supervisor.start_link([
      {RakNet.Server, %{
        port: 19132,
        guid: <<0x8d, 0xe7, 0xee, 0x79, 0x41, 0xe6, 0xf2, 0xce>>,
        client_module: BedrockServer.Client.State,
        client_data: %{},
      }},
      #{BedrockServer.SessionServer, %{}},
      {Registry, keys: :unique, name: BedrockServer.Client},
    ], opts)
  end
end
