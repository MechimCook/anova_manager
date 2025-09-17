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

  def get_APC_wifi_list() do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :not_connected}

      pid ->
          state = :sys.get_state(pid)
          {:ok, Map.get(state, :EVENT_APC_WIFI_LIST, [])}
    end
  end

  def handle_frame({:text, msg}, state) do
    with {:ok, msg} <- Jason.decode(msg) do
      case Map.get(msg, "command") do
        "EVENT_APC_WIFI_LIST" ->
          {:ok, %{state | EVENT_APC_WIFI_LIST: Map.get(msg, "payload")}}
        _ ->
          {:ok, state}
      end
    else
      {:error, _} -> IO.puts("⚠️ Failed to decode message: #{msg}")
        {:ok, state}
    end
  end

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
token="anova-eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiJDRVFNeGJlYjhXTlg0ZmJnVGRPOU1NM2RzQXYxIiwiY3JlYXRlZEF0IjoxNzU3NjE5OTQ5MzE3fQ.UX75mNaGwqiHxojpVsMbwoMJZ-rEVyEpSoEaqwP2Fc0"
{:ok, pid} = AnovaWebSocket.connect(token)
AnovaWebSocket.get_APC_wifi_list()
AnovaWebSocket.disconect()
