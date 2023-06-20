defmodule BedrockServer.Packet do

  # The current codex version.
  @codec_ver 567

  @packet_ids %{
    :network_settings => 0x8f,
    :network_setting_request => 0xc1,
  }

  defstruct [
    #:sender_sub_id,
    #:recipient_sub_id,

    packet_id: nil,
    packet_buf: nil,
  ]

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
    do: RakNet.Packet.encode_int16(v)

  @doc """
  Encode a byte sized integer.
  """
  def encode_byte(v),
    do: RakNet.Packet.encode_int8(v)

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

  def decode_packet(buffer) do
    <<
      packet_id::size(8),
      _pid::size(8),
      _sid::size(8),
      _rid::size(8),
      packet_buf::binary
    >> = buffer

    case to_atom(packet_id) do
      :error -> raise "Unknown packet id"
      packet_id -> %__MODULE__{
        packet_id: packet_id,
        packet_buf: packet_buf,
      }
    end
  end

end
