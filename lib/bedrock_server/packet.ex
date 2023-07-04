defmodule BedrockServer.Packet do

  import Bitwise

  # The current codex version.
  @codec_ver 567

  @packet_ids %{
    :batch => 0xfe,

    :login => 0x01,

    :network_settings => 0x8f,
    :network_setting_request => 0xc1,
  }

  defstruct [
    #:sender_sub_id,
    #:recipient_sub_id,

    packet_id: nil,
    packet_buf: nil,
  ]

  @send_shift 10
  @recv_shift 12

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
  Encodes a batch of packets.
  """
  def encode_batch(packets) when is_bitstring(packets),
    do: encode_batch([packets])

  def encode_batch(packets) when is_list(packets) do
    batch = packets
      |> Enum.map(fn packet ->
        length = byte_size(packet)
          |> encode_uvarint()
        length <> packet
      end)
      |> Enum.join()

    <<to_binary(:batch), batch::binary>>
  end

  @doc """
  Encode a packet header.
  """
  def encode_header(id, send_sid, recv_sid) do
    encode_uvarint(
      to_binary(id)
      |> bor(bsr(send_sid, @send_shift))
      |> bor(bsr(recv_sid, @recv_shift))
    )
  end

  @doc """
  Encode an unsigned variable size int.
  """
  def encode_uvarint(v) when v in 0..4_294_967_295,
    do: encode_uvarint(v, "")

  defp encode_uvarint(v, a) when v > 127,
    do: encode_uvarint(v >>> 7, <<a::binary, 1::1, v::7>>)

  defp encode_uvarint(v, a) when v <= 127,
    do: <<a::binary, 0::1, v::7>>

  @doc """
  Encode a boolean value.
  """
  def encode_bool(v),
    do: RakNet.Packet.encode_bool(v)

  @doc """
  Encode a short integer.
  """
  def encode_short(v),
    do: RakNet.Packet.encode_int16(v)

  def encode_ushort(v) do
    <<>>
      <> encode_byte(v)
      <> encode_byte(v <<< 8)
  end

  @doc """
  Encode a byte sized integer.
  """
  def encode_byte(v),
    do: RakNet.Packet.encode_int8(v)

  @doc """
  Encode a single-precision 32-bit floating point number.
  """
  def encode_float(v),
    do: <<v::32-float>>

  @doc """
  Encode a double-precision 64-bit floating point number.
  """
  def encode_double(v),
    do: <<v::64-float>>

  def decode_packet(buffer) do
    <<
      packet_id::size(8),
      _pid::size(8),
      _sid::size(8),
      _rid::size(8),
      packet_buf::binary
    >> = buffer

    case to_atom(packet_id) do
      :error -> raise "Unknown packet id #{packet_id}"
      packet_id -> %__MODULE__{
        packet_id: packet_id,
        packet_buf: packet_buf,
      }
    end
  end

  @doc """
  Decode a json string.
  """
  def decode_json(buffer) do
    {len1, buffer} = decode_int(buffer)
    {len2, buffer} = decode_uvarint(buffer)

    IO.inspect [len1, len2]

    {<<>>, buffer}
  end

  @doc """
  Decode a UTF-8 string prefixed with its size in bytes as varint.
  """
  def decode_string(buffer),
    do: RakNet.Packet.decode_string(buffer)

  @doc """
  Decode a 32-bit signed integer.
  """
  def decode_int(buffer) do
    <<value::32-integer, rest::binary>> = buffer
    {value, rest}
  end

  @doc """
  Decode a 32-bit unsigned integer.
  """
  def decode_uint(buffer) do
    <<value::32-integer-unsigned, rest::binary>> = buffer
    {value, rest}
  end

  @doc """
  Decode a variable-sized little-endian int.
  """
  def decode_uvarint(buffer),
    do: RakNet.Packet.decode_varint(buffer)

end
