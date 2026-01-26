defmodule AnovaManager.WebSocketHandler do
  use WebSockex
  require Logger

  @moduledoc false

  # When connected, notify the parent GenServer and forward messages
  def handle_connect(_conn, state) do
    parent = Map.get(state, :parent)
    if parent, do: send(parent, {:ws_connected, self()})
    {:ok, state}
  end

  def handle_cast(:close, state) do
    Logger.info("🔌 Disconnecting from server")
    {:close, state}
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded} ->
        parent = Map.get(state, :parent)
        if parent, do: send(parent, {:ws_message, decoded})

        # If it's the wifi list event, also notify discovery completion
        if Map.get(decoded, "command") == "EVENT_APC_WIFI_LIST" do
          send(parent, {:discovery_complete, decoded["payload"]})
        end

        {:ok, state}

      {:error, _} ->
        Logger.warning("⚠️ Failed to decode message: #{msg}")
        {:ok, state}
    end
  end
end


defmodule AnovaWebSocket do
  @moduledoc "Compatibility wrapper; prefer AnovaManager.SousVide for supervised usage"

  defdelegate connect(token), to: AnovaManager.SousVide
  defdelegate disconnect(), to: AnovaManager.SousVide
  defdelegate start_cooking(payload), to: AnovaManager.SousVide
  defdelegate stop_cooking(payload), to: AnovaManager.SousVide
  defdelegate set_target_temperature(cooker_id, type, temp, opts \\ []), to: AnovaManager.SousVide
  defdelegate get_APC_wifi_list(), to: AnovaManager.SousVide
end
