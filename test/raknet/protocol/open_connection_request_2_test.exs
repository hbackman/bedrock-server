defmodule RakNet.Protocol.OpenConnectionRequest2Test do
  use ExUnit.Case

  alias RakNet.Protocol.OpenConnectionRequest2
  import RakNet.Packet

  defp make_buffer(with_msg) do
    if with_msg,
      do: <<>> <> encode_msg(:open_connection_request_2),
    else: <<>>
      <> offline()
      <> encode_ip(4, {255, 255, 255, 255}, 19132)
      <> encode_int16(150)
      <> encode_int64(123456789)
  end

  test "encode" do
    {status, message} = %OpenConnectionRequest2{
      mtu: 150,
      client_id: 123456789,
    } |> OpenConnectionRequest2.encode()

    assert status == :error
    assert message == :not_implemented
  end

  test "decode" do
    {:ok, packet} = make_buffer(false)
      |> OpenConnectionRequest2.decode()

    assert packet.mtu == 150
    assert packet.client_id == 123456789
  end
end
