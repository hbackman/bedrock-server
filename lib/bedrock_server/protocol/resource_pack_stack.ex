defmodule BedrockServer.Protocol.ResourcePackStack do
  @moduledoc """
  | Field Name          | Type                | Notes          |
  |---------------------|---------------------|----------------|
  | Packet ID           | 0x07                |                |
  | Force Accept        | boolean             |                |
  | Resource Pack Entry | ResourcePackEntry[] | Not supported. |
  | Behavior Pack Entry | BehaviorPackEntry[] | Not supported. |
  | Experiments         | Experiements        | Not supported. |
  """

  alias BedrockServer.Protocol.Packet
  import BedrockServer.Packet

  @behaviour Packet

  defstruct []

  @impl Packet
  def encode(%__MODULE__{} = _packet) do
    buffer = <<>>
      <> encode_header(:resource_pack_stack)
      <> encode_bool(false)
      <> encode_uvarint(0)
      <> encode_uvarint(0)
      <> encode_string("1.20.0")
      <> encode_intle(0)
      <> encode_bool(false)
    {:ok, buffer}
  end

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end
end
