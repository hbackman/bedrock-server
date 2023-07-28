defmodule BedrockServer.Protocol.ResourcePacksInfo do
  @moduledoc """
  | Field Name         | Type           | Notes          |
  |--------------------|----------------|----------------|
  | Packet ID          | 0x06           |                |
  | Force Accept       | boolean        |                |
  | Scripting Enabled  | boolean        |                |
  | Force Server Packs | boolean        |                |
  | Behavior Packs     | BehaviorPack[] | Not supported. |
  | Resource Packs     | ResourcePack[] | Not supported. |
  """

  alias BedrockServer.Protocol.Packet
  import BedrockServer.Packet

  @behaviour Packet

  defstruct []

  @impl Packet
  def encode(%__MODULE__{} = _packet) do
    buffer = <<>>
      <> encode_header(:resource_packs_info)
      <> encode_bool(false)
      <> encode_bool(false)
      <> encode_bool(false)
      <> encode_short(0)
      <> encode_short(0)
    {:ok, buffer}
  end

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end
end
