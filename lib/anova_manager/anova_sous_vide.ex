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

  def start_cooking(payload), do: send_command("CMD_APC_START", payload)

  @doc "Stop cooking for the given cooker (pass payload with cookerId/type)."
  def stop_cooking(payload), do: send_command("CMD_APC_STOP", payload)

   @doc """
  Set target temperature and timer for the given cooker.
  Example: set_target_temperature(cooker_id, type, 55, unit: \"C\", timer: 60)
  """
  def set_target_temperature(cooker_id, type, target_temperature, opts \\ []) do
    unit = Keyword.get(opts, :unit, "C")
    timer = Keyword.get(opts, :timer, 0)

    payload = %{
      cookerId: cooker_id,
      type: type,
      unit: unit,
      targetTemperature: target_temperature,
      timer: timer
    }

    send_command("CMD_APC_SET", payload)
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

  defp send_command(command, payload \\ %{}) when is_binary(command) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :not_connected}

      _pid ->
        message =
          %{
            command: command,
            requestId: UUID.uuid4(),
            payload: payload
          }
          |> Jason.encode!()
          |> IO.inspect(label: "➡️ Sending command")

        WebSockex.send_frame(__MODULE__, {:text, message})
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
