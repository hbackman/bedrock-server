defmodule AetheriaServer do
  use GenServer
  
  # Use a factory to start up the server. This runs from the caller context.
  def start_link(port) do
    GenServer.start_link(__MODULE__, port)
      |> IO.inspect(label: 'start_link/1')
  end

  # Initialize the server. This runs in the server context.
  def init(port) do
    # Use erlang's `gen_udp` module to open a socket.
    # With options:
    #   - binary: request that data be returned as `String`.
    #   - active: gen_udp will handle data reception and send us a message `{:udp, socket, address, port ,data}` when new data arrives.
    :gen_udp.open(port, [:binary, active: true])
  end

  # Handle incoming udp data.
  def handle_info({:udp, _socket, _address, _port, data}, socket) do
    # Call a new function so that we can pattern match.
    handle_packet(data, socket)
  end

  # Handle a a "quit" packet.
  defp handle_packet("quit\n", socket) do
    IO.puts("Received: quit. Closing down...")

    # Close the socket.
    :gen_udp.close(socket)

    # GenServer will understand this as "stop the server".
    {:stop, :normal, nil}
  end

  # Handle a data packet.
  defp handle_packet(data, socket) do
    IO.puts("Received: #{String.trim data}")

    # GenServer will understand this as "continue waiting for the next message"
    {:noreply, socket}
  end

end
