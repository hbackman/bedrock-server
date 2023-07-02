defmodule RakNetTest.Protocol.OpenConnectionRequest1Test do
  use ExUnit.Case

  alias RakNet.Protocol.OpenConnectionRequest1
  import RakNet.Packet

  defp make_buffer(with_msg \\ true) do
    buffer = if with_msg,
      do: <<>> <> encode_msg(:open_connection_request_1),
    else: <<>>
    buffer
      <> offline()
      <> encode_int8(10)
      <> String.duplicate(<<0>>, 150)
  end

  test "encode" do
    {:ok, packet} = %OpenConnectionRequest1{
      protocol: 10,
      mtu: 150,
    } |> OpenConnectionRequest1.encode()

    assert packet == make_buffer()
  end

  test "decode" do
    {:ok, packet} = make_buffer(false)
      |> OpenConnectionRequest1.decode()

    assert packet.protocol == 10
    assert packet.mtu == 150
  end
end
