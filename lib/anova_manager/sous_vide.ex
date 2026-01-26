defmodule AnovaManager.SousVide do
  @moduledoc """
  GenServer that supervises and manages a WebSocket connection to the Anova service.

  It manages reconnection/backoff, queues outgoing commands while disconnected,
  and forwards JSON messages from the socket to the GenServer so callers can
  request data like the WiFi list.
  """
  use GenServer
  require Logger

  @base_url "wss://devices.anovaculinary.io"
  @initial_backoff 1_000
  @max_backoff 30_000

  # dynamic helpers so tests can override backoff and ws module via application env
  defp ws_module(), do: Application.get_env(:anova_manager, :ws_module, WebSockex)
  defp initial_backoff(), do: Application.get_env(:anova_manager, :initial_backoff, @initial_backoff)

  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Connect the supervised WebSocket using given token"
  def connect(token) when is_binary(token) do
    GenServer.call(__MODULE__, {:connect, token}, 10_000)
  end

  def disconnect do
    GenServer.call(__MODULE__, :disconnect)
  end

  def start_cooking(payload) when is_map(payload) do
    GenServer.call(__MODULE__, {:schedule_cooking, payload})
  end

  @doc "Enqueue a job explicitly (keeps it in the queue until flushed)"
  def enqueue(payload) when is_map(payload) do
    GenServer.call(__MODULE__, {:enqueue, payload})
  end

  def stop_cooking(payload) when is_map(payload) do
    GenServer.call(__MODULE__, {:stop_cooking, payload})
  end

  def set_target_temperature(cooker_id, type, target_temperature, opts \\ []) do
    unit = Keyword.get(opts, :unit, "F")
    timer = Keyword.get(opts, :timer, 0)

    payload = %{
      cookerId: cooker_id,
      type: type,
      unit: unit,
      targetTemperature: target_temperature,
      timer: timer
    }

    start_cooking(payload)

  end

  def get_APC_wifi_list do
    GenServer.call(__MODULE__, :get_APC_wifi_list)
  end

  @doc "Return current runtime status for introspection"
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Server callbacks
  def init(_opts) do
    token = System.get_env("token")

    state = %{
      token: nil,
      ws_pid: nil,
      connected: false,
      queue: [],
      backoff: initial_backoff(),
      EVENT_APC_WIFI_LIST: [],
      # last known EVENT_APC_STATE payload
      last_apc_state: nil
    }

    # if token is present in env, attempt async connect so init doesn't block
    if token do
      send(self(), {:auto_connect, token})
    end

    {:ok, state}
  end

  defp do_connect(token, state) do
    uri = "#{@base_url}?token=#{token}&supportedAccessories=APC,APO"
    ws = ws_module()

    case ws.start_link(uri, AnovaManager.WebSocketHandler, %{parent: self(), EVENT_APC_WIFI_LIST: []}) do
      {:ok, pid} ->
        Process.monitor(pid)
        Logger.info("Connected WebSocket (pid=#{inspect(pid)})")
        {:ok, pid, %{state | token: token, ws_pid: pid, connected: true, backoff: initial_backoff()}}

      {:error, reason} ->
        Logger.warning("Failed to start WebSocket: #{inspect(reason)}; scheduling reconnect")
        schedule_reconnect(state.backoff)
        {:error, reason, %{state | token: token}}
    end
  end

  def handle_call({:connect, token}, _from, state) do
    case do_connect(token, state) do
      {:ok, pid, new_state} ->
        {:reply, {:ok, pid}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call(:disconnect, _from, %{ws_pid: nil} = state), do: {:reply, {:error, :not_connected}, state}

  def handle_call(:disconnect, _from, state) do
    pid = state.ws_pid
    ws = ws_module()
    ws.cast(pid, :close)
    {:reply, :ok, %{state | ws_pid: nil, connected: false}}
  end

  def handle_call({:schedule_cooking, %{timer: timer} = payload}, _from, state) do
        Process.send_after(self(), {:start_cooking, payload}, timer)
        {:reply, :ok, state}
  end

  def handle_call({:stop_cooking, payload}, _from, %{connected: true, ws_pid: pid} = state) do
    send_command(pid, "CMD_APC_STOP", payload)
    {:reply, :ok, state}
  end

  def handle_call({:stop_cooking, payload}, _from, state) do
    {:reply, {:queued, payload}, %{state | queue: state.queue ++ [{:stop_cooking, payload}]}}
  end

  def handle_call({:enqueue, payload}, _from, state) do
    {:reply, {:enqueued, payload}, %{state | queue: state.queue ++ [{:start_cooking, payload}]}}
  end

  def handle_call(:get_APC_wifi_list, _from, state) do
    {:reply, {:ok, Map.get(state, :EVENT_APC_WIFI_LIST, [])}, state}
  end

  def handle_call(:status, _from, state) do
    status = %{
      connected: state.connected,
      has_token: not is_nil(state.token),
      queue: state.queue,
      wifi_list: Map.get(state, :EVENT_APC_WIFI_LIST, []),
      last_apc_state: state.last_apc_state,
      backoff: state.backoff
    }

    {:reply, status, state}
  end

  def handle_info({:start_cooking, payload}, %{connected: true, ws_pid: pid} = state) do
    send_command(pid, "CMD_APC_START", payload)
    {:noreply, state}
  end

  def handle_info({:start_cooking, payload}, state) do
    {:noreply, %{state | queue: state.queue ++ [{:start_cooking, payload}]}}
  end

  def handle_info({:auto_connect, token}, state) do
    # attempt an async connect during initialization
    case do_connect(token, state) do
      {:ok, _pid, new_state} -> {:noreply, new_state}
      {:error, _reason, new_state} -> {:noreply, new_state}
    end
  end

  # handle messages from the WebSocket handler
  def handle_info({:ws_connected, pid}, state) do
    Logger.info("WebSocket handler connected: #{inspect(pid)}")

    state = %{state | ws_pid: pid, connected: true, backoff: @initial_backoff}
    flush_queue(state)
  end

  def handle_info({:discovery_complete, payload}, state) do
    Logger.info("Device discovery complete: #{inspect(payload)}")
    {:noreply, %{state | EVENT_APC_WIFI_LIST: payload}}
  end

  def handle_info({:ws_message, %{"command" => "EVENT_APC_STATE", "payload" => payload}}, state) do
    Logger.info("Received EVENT_APC_STATE: #{inspect(payload)}")
    {:noreply, %{state | last_apc_state: payload}}
  end

  def handle_info({:ws_message, msg}, state) do
    Logger.debug("WS message: #{inspect(msg)}")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("WebSocket down: #{inspect(reason)}; will attempt reconnect")
    new_backoff = backoff_increase(state.backoff)
    schedule_reconnect(new_backoff)
    {:noreply, %{state | ws_pid: nil, connected: false, backoff: new_backoff}}
  end

  def handle_info(:reconnect, state) do
    if state.token do
      Logger.info("Attempting reconnect")
      ws = ws_module()

      case ws.start_link("#{@base_url}?token=#{state.token}&supportedAccessories=APC,APO", AnovaManager.WebSocketHandler, %{parent: self(), EVENT_APC_WIFI_LIST: []}) do
        {:ok, pid} ->
          Process.monitor(pid)
          {:noreply, %{state | ws_pid: pid, connected: true, backoff: initial_backoff()}}

        {:error, _} ->
          schedule_reconnect(state.backoff)
          {:noreply, %{state | connected: false, backoff: backoff_increase(state.backoff)}}
      end
    else
      {:noreply, state}
    end
  end

  defp send_command(pid, command, payload) do
    message = %{
      command: command,
      requestId: UUID.uuid4(),
      payload: payload
    }
    |>IO.inspect()
    |> Jason.encode!()

    ws = ws_module()
    ws.send_frame(pid, {:text, message})
  end

  defp flush_queue(%{queue: []} = state), do: {:noreply, state}

  defp flush_queue(%{queue: queue, ws_pid: pid} = state) when not is_nil(pid) do
    Enum.each(queue, fn
      {:start_cooking, payload} -> send_command(pid, "CMD_APC_START", payload)
      {:stop_cooking, payload} -> send_command(pid, "CMD_APC_STOP", payload)
      _ -> :ok
    end)

    {:noreply, %{state | queue: []}}
  end

  defp schedule_reconnect(ms) when is_integer(ms) and ms > 0 do
    # schedule reconnect using given backoff
    Process.send_after(self(), :reconnect, ms)
  end

  # Exposed for tests to trigger a reconnect
  def trigger_reconnect do
    send(__MODULE__, :reconnect)
  end

  defp backoff_increase(current) do
    min(current * 2, @max_backoff)
  end
end
