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

end
