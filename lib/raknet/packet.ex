defmodule RakNet.Packet do

  alias RakNet.Reliability
  alias RakNet.Message

  @moduledoc """
  Base serialization and deserialization routines for packets.
  """
  import Bitwise

  # ------------------------------------------------------------
  # Macros
  # ------------------------------------------------------------

  defmacro timestamp do
    quote do: size(64)
  end

  defmacro ip(version) do
    case version do
      4 -> quote do: size(56)
      6 -> quote do: nil # todo
    end
  end

  defmacro id() do
    quote do: size(8)
  end

  defmacro uint8 do
    quote do: big-size(8)
  end

  # ------------------------------------------------------------
  # Decode
  # ------------------------------------------------------------

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
    <<reliability::unsigned-size(3), has_split::unsigned-size(5), data::binary>> = data

    is_reliable = Reliability.is_reliable?(reliability)
    is_sequenced = Reliability.is_sequenced?(reliability)

    # Decode the length.
    <<length::size(16), data::binary>> = data
    length = trunc(Float.ceil(length / 8))

    # Decode sequence.
    {message_index, data} =
      if is_sequenced or is_reliable do
        <<message_index::little-size(24), rest::binary>> = data
        {message_index, rest}
      else
        {nil, data}
      end

    # Decode order.
    {order_index, order_channel, data} =
      if is_sequenced do
        <<order_index::little-size(24), order_channel::size(8), rest::binary>> = data
        {order_index, order_channel, rest}
      else
        {nil, nil, data}
      end

    # Decode split.
    {split_count, split_id, split_index, data} =
      if has_split > 0 do
        <<
          split_count::size(32),
          split_id   ::size(16),
          split_index::size(32),
          rest::binary
        >> = data
        {split_count, split_id, split_index, rest}
      else
        {nil, nil, nil, data}
      end

    # Decode buffer.
    length = length - 1

    <<
      msg_id::binary-size(1),
      msg_bf::binary-size(length),
      rest::binary
    >> = data

    # The message is sometimes a minecraft specific message. This doesnt match anything
    # in the message module. I will probably have to wait unwrapping the message id so
    # that a custom packet can implement the lookup.

    {%Reliability.Packet{
      reliability: '',

      has_split: has_split,

      order_index: order_index,
      order_channel: order_channel,

      split_id: split_id,
      split_count: split_count,
      split_index: split_index,

      sequencing_index: if(is_reliable, do: nil, else: message_index),
      message_index: if(is_reliable, do: message_index, else: nil),
      message_length: length,
      message_id: Message.name(msg_id),
      message_buffer: msg_bf,
    }, rest}
  end

  @doc """
  Decodes a variable-size integer.
  """
  def decode_varint(data) when is_binary(data),
    do: decode_varint(data, 0, 0)

  defp decode_varint(<<1::1, byte::7, rest::binary>>, num_read, acc) when num_read < 5 do
    decode_varint(rest, num_read + 1, acc + (byte <<< (7 * num_read)))
  end

  defp decode_varint(<<0::1, byte::7, rest::binary>>, num_read, acc) do
    result = acc + (byte <<< (7 * num_read))
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

  # ------------------------------------------------------------
  # Encode
  # ------------------------------------------------------------

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
  Encodes a string.
  """
  def encode_string(value) when is_bitstring(value) do
    strlen = encode_uint16(byte_size(value))
    <<strlen::binary, value::binary>>
  end

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

  @doc """
  Encodes a timestamp.
  """
  def encode_timestamp(time) do
    <<time::timestamp>>
  end

end
