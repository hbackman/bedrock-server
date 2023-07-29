defmodule RakNet.Protocol.OpenConnectionReply1Test do
  use ExUnit.Case

  alias RakNet.Protocol.OpenConnectionReply1
  import RakNet.Packet

  defp make_buffer(with_msg \\ true) do
    buffer = if with_msg,
      do: <<>> <> encode_msg(:open_connection_reply_1),
    else: <<>>
    buffer
      <> offline()
      <> encode_int64(123456789)
      <> encode_bool(false)
      <> encode_int16(150)
  end

  test "encode" do
    {:ok, packet} = %OpenConnectionReply1{
      server_id: 123456789,
      use_security: false,
      mtu: 150,
    } |> OpenConnectionReply1.encode()

    assert packet == make_buffer()
  end

  test "decode" do
    {:ok, packet} = make_buffer(false)
      |> OpenConnectionReply1.decode()

    assert packet.server_id == 123456789
    assert packet.use_security == false
    assert packet.mtu == 150
  end
end
