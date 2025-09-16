defmodule AnovaWebSocket do
  use WebSockex

  @base_url "wss://devices.anovaculinary.io"

  def connect(token) do
    uri = "#{@base_url}?token=#{token}&supportedAccessories=APC,APO"

    case WebSockex.start_link(uri, __MODULE__, %{discovered?: false}, name: __MODULE__) do
      {:ok, pid} ->
        wait_for_device_discovery()
        {:ok, pid}

      {:error, reason} ->
        IO.puts("❌ Connection failed: #{inspect(reason)}")
        {:error, reason}
    end
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
