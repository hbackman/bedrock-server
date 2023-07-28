defmodule BedrockServer.Protocol.StartGame do

  alias BedrockServer.Protocol.Packet

  @behaviour Packet

  defstruct [
    #:entity_unique_id,
    #:entity_runtime_id,
    #:player_gamemode,
    #:player_position,
    #:player_rotation,
  ]

  @impl Packet
  def encode(%__MODULE__{} = _packet) do
    {:ok, <<>>}
  end

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end
end
