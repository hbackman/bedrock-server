defmodule BedrockProtocol.Message do

  # The current codex version.
  @codec_ver 567

  @packet_ids %{
    # Minecraft will send these to see if it can discover the server. Not replying
    # will prevent the client from joining.
    :id_unconnected_ping => 0x01,
    :id_unconnected_pong => 0x1c,

    # Minecraft will send these when joining the server.
    :id_open_connection_request_1 => 0x05,
    :id_open_connection_reply_1   => 0x06,

    :id_open_connection_request_2 => 0x07,
    :id_open_connection_reply_2   => 0x08,

    # Connection request.
    :id_client_connect => 0x09,

    # Connection was successful.
    :id_server_handshake => 0x10,

    # Connection failed.
    :id_connection_attempt_failed => 0x11,

    # Connection was lost.
    :id_connection_lost => 0x16,

    :id_data_packet_0 => 0x80,
    :id_data_packet_1 => 0x81,
    :id_data_packet_2 => 0x82,
    :id_data_packet_3 => 0x83,
    :id_data_packet_4 => 0x84,
    :id_data_packet_5 => 0x85,
    :id_data_packet_6 => 0x86,
    :id_data_packet_7 => 0x87,
    :id_data_packet_8 => 0x88,
    :id_data_packet_9 => 0x89,
    :id_data_packet_A => 0x8A,
    :id_data_packet_B => 0x8B,
    :id_data_packet_C => 0x8C,
    :id_data_packet_D => 0x8D,
    :id_data_packet_E => 0x8E,
    :id_data_packet_F => 0x8F,
    :id_nack          => 0xA0,
    :id_ack           => 0xC0
  }

  # "Magic" bytes used to distinguish offline messages from garbage
  def offline, do: <<0x00, 0xff, 0xff, 0x00, 0xfe, 0xfe, 0xfe, 0xfe, 0xfd, 0xfd, 0xfd, 0xfd, 0x12, 0x34, 0x56, 0x78>>

  @doc """
  The message atom name for the message. Default to :error.
  """
  def name(message_binary) when is_integer(message_binary) do
    @packet_ids
      |> Map.new(fn {name, val} -> {val, name} end)
      |> Map.get(message_binary, :error)
  end

  @doc """
  The binary value for a message name.
  """
  def binary(message_name) when is_atom(message_name) do
    @packet_ids
      |> Map.fetch!(message_name)
  end

  @doc "The current Unix timestamp, in milliseconds"
  def timestamp(offset \\ 0), do: :os.system_time(:millisecond) - offset

  @doc "A 64-bit unique ID"
  def unique_id(), do: <<timestamp()::size(48), :rand.uniform(65_536)::size(16)>>

end