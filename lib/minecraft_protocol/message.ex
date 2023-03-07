defmodule BedrockProtocol.Message do

  # The current codex version.
  @codec_ver 567

  @packet_ids %{
    # Minecraft will send these to see if it can discover the server. Not replying
    # will prevent the client from joining.
    :id_unconnected_ping => 0x01,
    :id_unconnected_pong => 0x1c,

    :id_open_connection_request_1 => 0x05,
    :id_open_connection_reply_1   => 0x06,

    :id_open_connection_request_2 => 0x07,
    :id_open_connection_reply_2   => 0x08,
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