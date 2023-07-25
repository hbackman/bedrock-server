defmodule BedrockServer.Protocol.StartGame do

  @moduledoc """
  | Field Name                             | Type             |
  |----------------------------------------|------------------|
  | Entity ID Self                         | signed var long  |
  | Entity ID Runtime                      | var long         |
  | Player Gamemode                        | signed var int   |
  | Spawn                                  | vector3          |
  | Rotation                               | vector2          |
  | Seed                                   | signed var int   |
  | Spawn Biome Type                       | short            |
  | Custom Biome Name                      | string           |
  | Dimension                              | signed var int   |
  | Generator                              | signed var int   |
  | World Gamemode                         | signed var int   |
  | Difficulty                             | signed var int   |
  | World Spawn                            | BlockCoordinates |
  | Has achievements disabled              | bool             |
  | Day cycle stop time                    | signed var int   |
  | EDU offer                              | signed var int   |
  | Has Education Edition features enabled | bool             |
  | Education Production ID                | string           |
  | Rain level                             | float            |
  | Lightning level                        | float            |
  | Has Confirmed Platform Locked Content  | bool             |
  | Is Multiplayer                         | bool             |
  | Broadcast to LAN                       | bool             |
  | Xbox Live Broadcast Mode               | var int          |
  | Platform Broadcast Mode                | var int          |
  | Enable commands                        | bool             |
  | Are texture packs required             | bool             |
  | GameRules                              | GameRules        |
  | Bonus Chest                            | bool             |
  | Map Enabled                            | bool             |
  | Permission Level                       | signed var int   |
  | Server Chunk Tick Range                | int              |
  | Has Locked Behavior Pack               | bool             |
  | Has Locked Resource Pack               | bool             |
  | Is from locked world template          | bool             |
  | Usa MSA Gamertags Only                 | bool             |
  | Is from world template                 | bool             |
  | Is world template option locked        | bool             |
  | Only spawn V1 villagers                | bool             |
  | Game Version                           | string           |
  | Limited World Width                    | int              |
  | Limited World Height                   | int              |
  | Is Nether Type                         | bool             |
  | Is Force Experimental Gameplay         | bool             |
  | Level ID                               | string           |
  | World name                             | string           |
  | Premium World Template Id              | string           |
  | Is Trial                               | bool             |
  | Movement type                          | var int          |
  | Movement rewind size                   | int              |
  | Server authoritative block breaking    | bool             |
  | Current Tick                           | Long LE          |
  | Enchantment Speed                      | signed var int   |
  | Block Properties                       | Block Properties |
  | Itemstates                             | Itemstates       |
  | Multiplayer Correlation ID             | string           |
  | Inventories server authoritative       | bool             |
  """

  alias BedrockServer.Protocol.Packet

  @behaviour Packet

  defstruct [
    :entity_unique_id,
    :entity_runtime_id,
    :player_gamemode,
    :player_position,
    :player_rotation,
  ]

  def encode(%__MODULE__{} = _packet) do
    {:ok, <<>>}
  end
end
