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

  defstruct [
    :compression_threshold,
    :compression_algorithm,

    enable_throttling: false,

    client_throttle_threshold: 0,
    client_throttle_scalar: 0,
  ]

  import BedrockServer.Packet

  @doc """
  Encode a disconnect packet.
  """
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
end
