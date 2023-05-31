defmodule BedrockServer.Packet do

  # The current codex version.
  @codec_ver 567

  @packet_ids %{
    :network_settings => 0x8f,
    :network_setting_request => 0xc1,
  }

  @doc """
  Returns the packet id atom from the given binary value. Defaults to :error.
  """
  def to_atom(packet_id) when is_integer(packet_id) do
    @packet_ids
      |> Map.new(fn {name, val} -> {val, name} end)
      |> Map.get(packet_id, :error)
  end

  def to_atom(packet_id) when is_bitstring(packet_id) do
    <<packet_bit, _::binary>> = packet_id
    to_atom(packet_bit)
  end

  def to_binary(packet_id) when is_atom(packet_id) do
    @packet_ids
      |> Map.fetch!(packet_id)
  end

  # ---------------------------------------------------------------------------
  # Encoding / Decoding
  # ---------------------------------------------------------------------------

  @doc """
  Encode a packet id.
  """
  def encode_id(id),
    do: <<to_binary(id)>>

  @doc """
  Encode a boolean value.
  """
  def encode_bool(v),
    do: RakNet.Packet.encode_bool(v)

  @doc """
  Encode a short integer.
  """
  def encode_short(v),
    do: RakNet.Packet.encode_uint16(v)

  @doc """
  Encode a byte sized integer.
  """
  def encode_byte(v),
    do: RakNet.Packet.encode_uint8(v)

  @doc """
  Encode a single-precision 32-bit floating point number.
  """
  def encode_float(v),
    do: <<v::float-32>>

  @doc """
  Encode a double-precision 64-bit floating point number.
  """
  def encode_double(v),
    do: <<v::float-64>>

end
