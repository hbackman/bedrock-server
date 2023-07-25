defmodule BedrockServer.Packet do
  import Bitwise

  # The current codex version.
  @codec_ver 567

  @packet_ids %{
    :batch => 0xfe,

    :login => 0x01,
    :play_status => 0x02,

    :disconnect => 0x05,

    :resource_packs_info => 0x06,
    :resource_pack_stack => 0x07,
    :resource_packs_client_response => 0x08,

    :network_settings => 0x8f,
    :network_settings_request => 0xc1,

    :client_cache_status => 0x81,

    :packet_violation_warning => 0x9c,
  }

  defstruct [
    packet_id: nil,
    packet_buf: nil,
  ]

  @pid_mask 0x3ff # Packet ID Mask
  @sub_mask 0x03  # Sub-Client ID Mask

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
  Macro for smaller decoders.
  """
  defmacro decode_using(buffer, type) do
    quote do
      <<v::unquote(type), r::binary>> = unquote(buffer)
      {v, r}
    end
  end

  @doc """
  Encodes a batch of packets.
  """
  def encode_batch(packets) when is_bitstring(packets),
    do: encode_batch([packets])

  def encode_batch(packets) when is_list(packets) do
    packets
      |> Enum.map(fn packet ->
        length = byte_size(packet)
          |> encode_uvarint()
        length <> packet
      end)
      |> Enum.join()
  end

  @doc """
  Encode a packet header.
  """
  def encode_header(id, send_sid \\ 0, recv_sid \\ 0)
  def encode_header(id, _send_sid, _recv_sid) do
    encode_uvarint(
      to_binary(id)
      #|> bor(bsl(send_sid, @send_shift))
      #|> bor(bsl(recv_sid, @recv_shift))
    )
  end

  @doc """
  Encodes a string.
  """
  def encode_string(v) when is_binary(v) do
    strlen = encode_uvarint(byte_size(v))
    <<strlen::binary, v::binary>>
  end

  def encode_ascii(v) when is_binary(v) do
    strlen = encode_uintle(byte_size(v))
    <<strlen::binary, v::binary>>
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
    do: <<v::8-integer>>

  @doc """
  Encode a 32-bit big-endian signed integer.
  """
  def encode_int(v),
    do: <<v::32-integer>>

  def encode_intle(v),
    do: <<v::32-integer-little>>

  def encode_uint(v),
    do: <<v::32-integer-unsigned>>

  def encode_uintle(v),
    do: <<v::32-integer-unsigned-little>>

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

  @doc """
  Decode minecraft packet.

  For now, it seems to work to ignore the 3 identifier bytes, but I may
  have to add support for these eventually.
  """
  def decode_packet(buffer) do
    {header, buffer} = decode_uvarint(buffer)

    packet_id = band(header, @pid_mask)

    # pid = header |> bsr(@send_shift) |> band(@sub_mask)
    # rid = header |> bsr(@recv_shift) |> band(@sub_mask)

    case to_atom(packet_id) do
      :error -> raise "Unknown packet id #{packet_id}"
      packet_id -> %__MODULE__{
        packet_id: packet_id,
        packet_buf: buffer,
      }
    end
  end

  @doc """
  Decode a UTF-8 string prefixed with its size in bytes as uintle.
  """
  def decode_string(buffer) do
    {strlen, buffer} = decode_uvarint(buffer)

    decode_using(buffer, binary-size(strlen))
  end

  def decode_ascii(buffer) do
    {strlen, buffer} = decode_uintle(buffer)

    decode_using(buffer, binary-size(strlen))
  end

  @doc """
  Decode a 32-bit big-endian signed integer.
  """
  def decode_int(buffer),
    do: decode_using(buffer, 32-integer)

  @doc """
  Decode a 32-bit little-endian signed integer.
  """
  def decode_intle(buffer),
    do: decode_using(buffer, 32-integer-little)

  @doc """
  Decode a 32-bit big-endian unsigned integer.
  """
  def decode_uint(buffer),
    do: decode_using(buffer, 32-integer-unsigned)

  @doc """
  Decode a 32-bit little-endian unsigned integer.
  """
  def decode_uintle(buffer),
    do: decode_using(buffer, 32-integer-unsigned-little)

  @doc """
  Decode a variable-sized little-endian int.
  """
  def decode_uvarint(buffer),
    do: RakNet.Packet.decode_varint(buffer)

end
