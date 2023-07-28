defmodule BedrockServer.Protocol.NetworkSettings do
  @moduledoc """
  | Field Name                | Type    | Notes          |
  |---------------------------|---------|----------------|
  | Packet ID                 | 0x8f    |                |
  | Compression Threshold     | short   |                |
  | Compression Algorithm     | short   |                |
  | Client Throttling         | boolean |                |
  | Client Throttle Threshold | byte    |                |
  | Client Throttle Scalar    | float   |                |
  """

  alias BedrockServer.Protocol.Packet
  import BedrockServer.Packet

  @behaviour Packet

  defstruct [
    :compression_threshold,
    :compression_algorithm,

    enable_throttling: false,

    client_throttle_threshold: 0,
    client_throttle_scalar: 0,
  ]

  @impl Packet
  def encode(%__MODULE__{} = packet) do
    buffer = <<>>
      <> encode_header(:network_settings)
      <> encode_ushort(packet.compression_threshold)
      <> encode_ushort(packet.compression_algorithm)
      <> encode_bool(packet.enable_throttling)
      <> encode_byte(packet.client_throttle_threshold)
      <> encode_float(packet.client_throttle_scalar)
    {:ok, buffer}
  end

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end
end
