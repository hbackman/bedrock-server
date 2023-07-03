defprotocol RakNet.Client do
  @doc """
  Handles a client connecting to the server. This should return the client after
  making any changes to it.
  """
  def connect(client, connection_pid, module_data)

  @doc """
  Handles an incoming game packet.
  """
  def receive(client, packet_buffer)

  @doc """
  Handles a client disconnecting from the server.
  """
  def disconnect(client)
end
