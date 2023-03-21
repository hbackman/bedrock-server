defmodule BedrockProtocol.Packet do

  alias BedrockProtocol.Message

  @moduledoc """
  Base serialization and deserialization routines for packets.
  """
  import Bitwise

  def decode_packets(data, packets \\ [])
  def decode_packets("", packets) do
    Enum.reverse(packets)
  end

  def decode_packets(data, packets) do
    {packet, rest} = decode_encapsulated(data)
    decode_packets(rest, [packet | packets])
  end

  @doc """
  Decode encapsulated messages.
  """
  def decode_encapsulated(data) do
    # Decode reliability.
    <<
      _rel::unsigned-size(3),
      _spt::unsigned-size(5),
      data::binary
    >> = data

    # Decode the length.
    <<length::size(16), data::binary>> = data

    # Decode message index.
    <<_msg_index::little-size(24), data::binary>> = data

    # Decode message ordering.
    #<<
    #  _org_index::little-size(24),
    #  _ord_channel::size(8),
    #  data::binary
    #>> = data

    # Decode the message.
    len = trunc(Float.ceil(length / 8))

    <<
      msg_id::binary-size(1),
      msg_bf::binary-size(len - 1),
      data::binary
    >> = data
    
    {{Message.name(msg_id), msg_bf}, data}
  end

  @doc """
  Decodes a variable-size integer.
  """
  def decode_varint(data) do
    decode_varint(data, 0, 0)
  end

  defp decode_varint(<<1::1, value::7, rest::binary>>, num_read, acc) when num_read < 5 do
    decode_varint(rest, num_read + 1, acc + (value <<< (7 * num_read)))
  end

  defp decode_varint(<<0::1, value::7, rest::binary>>, num_read, acc) do
    result = acc + (value <<< (7 * num_read))
    <<result::32-signed>> = <<result::32-unsigned>>
    {result, rest}
  end

  defp decode_varint(_, num_read, _) when num_read >= 5, do: {:error, :too_long}
  defp decode_varint("", _, _), do: {:error, :too_short}

  @doc """
  Decodes a string.
  """
  def decode_string(data) do
    {strlen, data} = decode_varint(data)
    <<string::binary-size(strlen), rest::binary>> = data
    {string, rest}
  end

  @doc """
  Encode encapsulated messages.
  """
  def encode_encapsulated(packets) when is_list(packets) do
    header = <<>>
      <> encode_msg(:data_packet_4)
      <> encode_seq_number(0)

    message = Enum.reduce(packets, <<>>, fn packet, msg ->
      len = bit_size(packet)

      msg <> encode_flag(0x60)  # RakNet Message flags
          <> encode_uint16(len) # RakNet Payload length
          <> encode_uint24(0)   # RakNet Reliable message ordering
          <> encode_uint24(0)   # RakNet Message ordering index
          <> encode_uint8(0)    # RakNet Message ordering channel
          <> packet
    end)

    header <> message
  end

  def encode_encapsulated(packets) when is_bitstring(packets),
    do: encode_encapsulated([packets])

  @doc """
  Encodes a boolean.
  """
  def encode_bool(false), do: <<0>>
  def encode_bool(true),  do: <<1>>

  def encode_uint24(value),
    do: <<value::big-size(24)>>

  def encode_uint16(value),
    do: <<value::big-size(16)>>

  def encode_uint8(value),
    do: <<value::big-size(8)>>

  @doc """
  Encodes an ip address.
  """
  def encode_ip(4, address, port) do
    {a1, a2, a3, a4} = address

    encode_uint8(4)     <>
    <<255-a1::size(8)>> <>
    <<255-a2::size(8)>> <>
    <<255-a3::size(8)>> <>
    <<255-a4::size(8)>> <>
    encode_uint16(port)
  end

  @doc """
  Encodes a string.
  """
  def encode_string(string) do
    #strlen = encode_varint(byte_size(string))
    #<<strlen::binary, string::binary>>
    <<string::binary>>
  end

  @doc """
  Encodes a sequence number. These are three bytes in size.
  """
  def encode_seq_number(num) do
    encode_uint24(num)
  end

  @doc """
  Encodes a message id.
  """
  def encode_msg(id) do
    <<Message.binary(id)>>
  end

  @doc """
  Encodes a packet flag.
  """
  def encode_flag(flag) when flag <= 255 do
    encode_uint8(flag)
  end

end