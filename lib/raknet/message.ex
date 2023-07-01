defmodule RakNet.Message do

  @packet_ids %{
    :connected_ping => 0x00,
    :connected_pong => 0x03,

    # Minecraft will send these to see if it can discover the server. Not replying
    # will prevent the client from joining.
    :unconnected_ping => 0x01,
    :unconnected_pong => 0x1c,

    # Minecraft will send these when joining the server.
    :open_connection_request_1 => 0x05,
    :open_connection_reply_1   => 0x06,

    :open_connection_request_2 => 0x07,
    :open_connection_reply_2   => 0x08,

    # Connection request.
    :client_connect => 0x09,
    # Connection was successful.
    :server_handshake => 0x10,

    :client_handshake => 0x13,
    :client_disconnect => 0x15,

    # Connection failed.
    :connection_attempt_failed => 0x11,

    # Connection was lost.
    :connection_lost => 0x16,

    :data_packet_0 => 0x80,
    :data_packet_1 => 0x81,
    :data_packet_2 => 0x82,
    :data_packet_3 => 0x83,
    :data_packet_4 => 0x84,
    :data_packet_5 => 0x85,
    :data_packet_6 => 0x86,
    :data_packet_7 => 0x87,
    :data_packet_8 => 0x88,
    :data_packet_9 => 0x89,
    :data_packet_A => 0x8A,
    :data_packet_B => 0x8B,
    :data_packet_C => 0x8C,
    :data_packet_D => 0x8D,
    :data_packet_E => 0x8E,
    :data_packet_F => 0x8F,

    :nack => 0xA0,
    :ack  => 0xC0,

    :game_packet   => 0xFE,
  }

  @doc """
  The message atom name for the message. Default to :error.
  """
  def name(message_binary) when is_integer(message_binary) do
    @packet_ids
      |> Map.new(fn {name, val} -> {val, name} end)
      |> Map.get(message_binary, :error)
  end

  def name(message_binary) when is_bitstring(message_binary) do
    <<message_bit, _::binary>> = message_binary
    name(message_bit)
  end

  @doc """
  The binary value for a message name.
  """
  def binary(message_name, wrap \\ false)
  def binary(message_name, false) when is_atom(message_name) do
    @packet_ids
      |> Map.fetch!(message_name)
  end

  def binary(message_name, true) when is_atom(message_name) do
    <<binary(message_name, false)>>
  end

  @doc "The current Unix timestamp, in milliseconds"
  def timestamp(offset \\ 0), do: :os.system_time(:millisecond) - offset

  @doc "A 64-bit unique ID"
  def unique_id(), do: <<timestamp()::size(48), :rand.uniform(65_536)::size(16)>>

end
