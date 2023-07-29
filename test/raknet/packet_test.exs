defmodule RakNet.PacketTest do
  use ExUnit.Case, async: true

  import RakNet.Packet

  describe "strings" do
    test "encode" do
      assert <<0, 0>> = encode_string("")
      assert <<0, 1, "a">> = encode_string("a")
      assert <<0, 2, "ab">> = encode_string("ab")
    end

    test "decode" do
      assert {"", ""} = decode_string(<<0, 0>>)
      assert {"a", ""} = decode_string(<<0, 1, "a">>)
      assert {"a", "b"} = decode_string(<<0, 1, "ab">>)
    end

    test "encode large" do
      a = String.duplicate("e", 255)
      assert <<0, 255, ^a::binary>> = encode_string(a)

      b = String.duplicate("e", 511)
      assert <<1, 255, ^b::binary>> = encode_string(b)
    end

    test "decode large" do
      a = String.duplicate("e", 255)
      assert {^a, ""} = decode_string(encode_string(a))

      b = String.duplicate("e", 511)
      assert {^b, ""} = decode_string(encode_string(b))
    end
  end

  describe "booleans" do
    test "encode" do
      assert <<0>> = encode_bool(false)
      assert <<1>> = encode_bool(true)
    end

    test "decode" do
      assert {false, ""} = decode_bool(<<0>>)
      assert {true, ""} = decode_bool(<<1>>)
    end
  end

  describe "integers" do
    test "encode int8" do
      assert <<0>> = encode_int8(0)
      assert <<1>> = encode_int8(1)
      assert <<1>> = encode_int8(257)
    end

    test "decode int8" do
      assert {0, "a"} = decode_int8(<<0, "a">>)
      assert {1, "b"} = decode_int8(<<1, "b">>)
    end

    test "encode int16" do
      assert <<0, 255>> = encode_int16(255)
      assert <<1, 255>> = encode_int16(511)
    end

    test "decode int16" do
      assert {255, "a"} = decode_int16(<<0, 255, "a">>)
      assert {511, "b"} = decode_int16(<<1, 255, "b">>)
    end

    test "encode int24" do
      assert <<0, 0, 1>> = encode_int24(1)
      assert <<0, 1, 1>> = encode_int24(257)
      assert <<1, 1, 1>> = encode_int24(65_793)
    end

    test "decode int24" do
      assert {1,      "a"} = decode_int24(<<0, 0, 1, "a">>)
      assert {257,    "a"} = decode_int24(<<0, 1, 1, "a">>)
      assert {65_793, "a"} = decode_int24(<<1, 1, 1, "a">>)
    end

    test "encode int64" do
      assert <<0, 0, 0, 0, 0, 0, 1, 0>> = encode_int64(256)
      assert <<0, 0, 0, 0, 1, 0, 0, 0>> = encode_int64(16777216)
      assert <<0, 0, 1, 0, 0, 0, 0, 0>> = encode_int64(1099511627776)
    end

    test "decode int64" do
      assert {256,      "a"} = decode_int64(<<0, 0, 0, 0, 0, 0, 1, 0, "a">>)
      assert {16777216, "a"} = decode_int64(<<0, 0, 0, 0, 1, 0, 0, 0, "a">>)
    end
  end

  test "encode ip" do
    <<4, 63, 87, 254, 254, 74, 188>> = encode_ip(4, {192, 168, 1, 1}, 19132)
  end

  test "encode sequence number" do
    <<1, 0, 0>> = encode_seq_number(1)
    <<1, 1, 0>> = encode_seq_number(257)
  end

  test "encode timestamp" do
    ts = 1690593585829

    <<^ts::size(64)>> = encode_timestamp(ts)
  end
end
