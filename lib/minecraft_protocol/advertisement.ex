defmodule BedrockProtocol.Advertisement do

  alias BedrockProtocol.Packet

  defstruct [
    edition: "MCPE",
    motd: "Dedicated Server",
    gamemode: "Survival",
    gamemodeId: 1,
    protocol: "568",
    version: "1.19.63",
    playerCount: 1,
    playerLimit: 10,
    serverId: -1,
    serverName: "Bedrock level",
    ipv4Port: -1,
    ipv6Port: -1,
    nintendo: 0,
  ]
  
  @doc """
  Advertisement constructor.
  """
  def new(attributes \\ %{}) do
    struct(%__MODULE__{}, attributes)
  end

  @doc """
  Encode the server advertisement as a buffer.
  """
  def to_buffer(ad) do
    buffer = Enum.join([
      ad.edition,
      ad.motd,
      ad.protocol,
      ad.version,
      ad.playerCount,
      ad.playerLimit,
      ad.serverId,
      ad.serverName,
      ad.gamemode,
      ad.gamemodeId,
      ad.ipv4Port,
      ad.ipv6Port,
      ad.nintendo,
    ], ";") <> ";"

    <<String.length(buffer)::little-size(16)>>
      |> :binary.decode_unsigned(:big)
      |> :binary.encode_unsigned(:little)
      |> Kernel.<>(buffer)
  end

end