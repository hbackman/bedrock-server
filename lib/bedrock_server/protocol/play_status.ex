defmodule BedrockServer.Protocol.PlayStatus do
  @moduledoc """
  | Field Name   | Type   | Notes          |
  |--------------|--------|----------------|
  | Packet ID    | 0x02   |                |
  | Status       | status |                |
  """

  alias BedrockServer.Protocol.Packet
  import BedrockServer.Packet

  @behaviour Packet

  defstruct [
    :status,
  ]

  @impl Packet
  def encode(%__MODULE__{} = packet) do
    buffer = <<>>
      <> encode_header(:play_status)
      <> encode_play_status(packet.status)
    {:ok, buffer}
  end

  @impl Packet
  def decode(_buffer) do
    {:ok, %__MODULE__{}}
  end

  defp encode_play_status(status) do
    encode_int(case status do
      # Sent after login has been successfully decoded and the player has
      # logged in.
      :login_success -> 0

      # Dislays "Could not connect: Outdated client!"
      :failed_client -> 1

      # Displays "Could not connect: Outdated server!"
      :failed_server -> 2

      # Sent after world data to spawn the player.
      :player_spawn -> 3

      # Displays "Unable to connect to world. You do not have access to
      # this world."
      :failed_invalid_tenant -> 4

      # Displays "This server is not running Minecraft: Education Edition.
      # Failed to connect."
      :failed_vanilla_edu -> 5

      # Displays "The server is running an incompatible edition of Minecraft.
      # Failed to connect."
      :failed_incompatible -> 6

      # Displays "Wow this server is popular! Check back later to see if
      # space opens up. Server Full"
      :failed_server_full -> 7
    end)
  end
end
