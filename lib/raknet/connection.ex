defmodule RakNet.Connection do
  use GenServer, restart: :transient

  alias RakNet.Packet
  alias RakNet.Reliability
  alias RakNet.Message
  alias RakNet.Protocol

  require Logger
  require Packet

  import Packet

  @sync_ms 200
  #@ping_ms 5000

  defmodule State do
    defstruct [
      host: {},
      port: nil,
      send: nil,
      server_identifier: nil,
      client_module: nil,
      client_data: %{},
      client: nil,
      # The :os.system_time(:millisecond) time at which we were created.
      base_time: 0,

      # The enqueued packets.
      packet_buffer: [],

      sequence_index: 0,
      order_index: -1,
      message_index: 0,

      ack_buffer: [],
      split_buffer: [],
    ]
  end

  @doc """
  Starts the connection without linking.
  """
  def start(%State{} = state),
    do: GenServer.start(__MODULE__, state)

  @doc """
  Instantiate the connection.
  """
  def start_link(%State{} = state),
    do: GenServer.start_link(__MODULE__, state)

  @doc """
  Terminate the connection.
  """
  def stop(connection_pid),
    do: GenServer.stop(connection_pid, :shutdown)

  @doc """
  Send a message to the client.
  """
  def send(connection_pid, reliability, message)

  def send(connection_pid, reliability, message) when is_bitstring(message) and is_atom(reliability) do
    GenServer.cast(connection_pid, {:send, reliability, message})
    {:ok, nil}
  end

  @doc """
  Handle a message from the client.
  """
  def handle_message(connection_pid, message_type, data) do
    GenServer.cast(connection_pid, {message_type, data})
  end

  @doc """
  Enqueue a packet.
  """
  def enqueue(connection, reliability, buffers) when is_atom(reliability) and is_list(buffers) do
    Enum.reduce(buffers, connection, fn buffer, connection ->
      enqueue(connection, reliability, buffer)
    end)
  end

  def enqueue(connection, reliability, buffer) when is_atom(reliability) and is_bitstring(buffer) do
    frame = %Reliability.Frame{
      reliability: reliability,
      message_buffer: buffer,
    }

    frame = if Reliability.ordered?(reliability),
      do: frame
        |> Map.put(:order_index, connection.order_index + 1),
    else: frame

    frame = if Reliability.sequenced?(reliability),
      do: frame
        |> Map.put(:order_index, connection.order_index),
    else: frame

    frame = if Reliability.reliable?(reliability),
      do: frame
        |> Map.put(:message_index, connection.message_index + 1),
    else: frame

    %{connection |
      packet_buffer: connection.packet_buffer ++ [frame],
      order_index: max_nil_safe(connection.order_index, frame.order_index),
      message_index: max_nil_safe(connection.message_index, frame.message_index),
    }
  end

  # Check which of the two values are bigger. If one is `nil`, then use
  # the other, and vice versa.
  #
  defp max_nil_safe(v1, v2) do
    cond do
      is_nil(v1) and is_nil(v2) ->
        nil
      is_nil(v1) -> v2
      is_nil(v2) -> v1
      true ->
        max(v1, v2)
    end
  end

  defp sync_enqueued_packets(connection) do
    %{ packet_buffer: buffer } = connection

    if Enum.empty?(buffer) do
      connection
    else
      <<>>
        <> Packet.encode_msg(:data_packet_0)
        <> Packet.encode(buffer, connection.sequence_index)
        |> IO.inspect
        |> connection.send.()

      %{connection |
        packet_buffer: [],
        sequence_index: connection.sequence_index + 1,
      }
    end
  end

  defp sync_ack_buffer(connection) do
    %{ack_buffer: buffer} = connection

    buffer
      |> Enum.reverse()
      |> Enum.each(fn seq ->
      <<>>
        <> Packet.encode_msg(:ack)
        <> Packet.encode_int16(1)
        <> Packet.encode_int8(1)
        <> Packet.encode_seq_number(seq)
        |> connection.send.()
    end)

    %{ connection |
      ack_buffer: [],
    }
  end

  # ---------------------------------------------------------------------------
  # Server Implementation
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(state) do
    {:ok, _} = :timer.send_interval(@sync_ms, :sync)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:sync, connection) do
    {:noreply, connection
      |> sync_enqueued_packets()
      |> sync_ack_buffer()
    }
  end

  @impl GenServer
  def handle_info(:ping, connection) do
   # connection.send.(make_ping_buffer(connection.base_time))

   # {:ok, buffer} = %RakNet.Protocol.ConnectedPong{
   #   ping_time: time,
   #   pong_time: RakNet.Server.timestamp(),
   # } |> RakNet.Protocol.ConnectedPong.encode()

    {:noreply, connection}
  end

  @impl GenServer
  def handle_cast({:send, reliability, message}, connection) do
    {:noreply, enqueue(connection, reliability, message)}
  end

  @impl GenServer
  def handle_cast({type, data}, connection) do
    connection = if Message.data_packet?(type),
      do: handle_encapsulated!(data, connection),
    else: handle_negotiation!(type, data, connection)

    {:noreply, connection}
  end

  # Handle an encapsulated message. These are sent after the client has established
  # the handshake with the server.
  #
  defp handle_encapsulated!(buffer, connection) do
    <<sequence::uint24le, buffer::binary>> = buffer

    frame_set = Packet.decode_packets(buffer)

    connection = Enum.reduce(frame_set, connection, fn frame, conn ->
      handle_frame!(frame, conn)
    end)

    connection |> push_ack(sequence)
  end

  # Handle a negotiation message. These are sent before the handshake.
  #
  defp handle_negotiation!(type, buffer, connection) do
    case Protocol.decode_packet(type, buffer) do
      {:ok, packet} ->
        handle_packet(packet, connection) |> elem(1)

      {:error, _} ->
        raise "Content negotiation failed for message #{type}"
    end
  end

  # Handle a frame.
  #
  defp handle_frame!(frame, connection) do
    if frame.has_split do
      connection
        |> push_split(frame)
        |> sync_split(frame)
    else
      # Extract the message.
      <<
        packet_id::id,
        packet_bf::binary,
      >> = frame.message_buffer

      # Convert to atom.
      packet_id = Message.name(packet_id)

      case Protocol.decode_packet(packet_id, packet_bf) do
        {:ok, packet} ->
          handle_packet(packet, connection) |> elem(1)

        {:error, _} ->
          raise "Encapsulated packet failed for message #{packet_id}"
      end
    end
  end

  # Handle a packet.
  #
  defp handle_packet(packet, connection) do
    RakNet.Protocol.handle(packet, connection)
  end

  defp push_ack(connection, sequence) when is_integer(sequence) do
    %{connection | ack_buffer: [sequence | connection.ack_buffer]}
  end

  defp push_split(connection, frame) do
    %{connection | split_buffer: [frame | connection.split_buffer]}
  end

  defp sync_split(connection, frame) do
    fragments = connection.split_buffer
      |> Enum.filter(& &1.split_id == frame.split_id)
      |> Enum.sort(& &1.split_index <= &2.split_index)

    if Enum.count(fragments) >= frame.split_count do
      assembled = fragments
        |> Enum.map(& &1.message_buffer)
        |> Enum.join()

      frame = %Reliability.Frame{
        reliability: frame.reliability,

        order_index: frame.order_index,
        order_channel: frame.order_channel,

        sequencing_index: frame.sequencing_index,

        message_index: frame.message_index,
        message_length: byte_size(assembled),
        message_buffer: assembled,
      }

      handle_frame!(frame, connection)
    else
      connection
    end
  end

end
