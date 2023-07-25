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

  defstruct []

  import BedrockServer.Packet

  @doc """
  Encode a resource packs info packet.
  """
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

end
