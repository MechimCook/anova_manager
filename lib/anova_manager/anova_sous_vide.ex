defmodule AnovaWebSocket do
  use WebSockex

  @base_url "wss://devices.anovaculinary.io"

  def connect(token) do
    uri = "#{@base_url}?token=#{token}&supportedAccessories=APC,APO"

    case WebSockex.start_link(uri, __MODULE__, %{EVENT_APC_WIFI_LIST: []}, name: __MODULE__) do
      {:ok, pid} ->
        wait_for_device_discovery()
        {:ok, pid}

      {:error, reason} ->
        IO.puts("❌ Connection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def disconect() do
    WebSockex.cast(__MODULE__, :close)
  end

  def handle_frame({:text, msg}, state) do
    with {:ok, msg_map} <- JSON.decode(msg) do
      state =
      case Map.get(msg_map, "command") do
      "EVENT_APC_WIFI_LIST" ->
        %{state | EVENT_APC_WIFI_LIST: Map.get(msg_map, "payload")}
      _ ->
        state
      end
      {:ok, state}
    else
        {:error, _} -> IO.puts("⚠️ Failed to decode message: #{msg}")
          {:ok, state}
    end
  end

  def

  def handle_cast(:close, state) do
    IO.puts("🔌 Disconnecting from server")
    {:close, state}
  end


  defp wait_for_device_discovery(timeout \\ 5_000) do
    receive do
      {:discovery_complete, _msg} ->
        :ok
    after
      timeout ->
        IO.puts("⚠️ Device discovery timed out")
        :error
    end
  end
end
