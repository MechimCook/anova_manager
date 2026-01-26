defmodule AnovaManager.SousVideTokenTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    # ensure tests control the WS module and backoff values
    Application.put_env(:anova_manager, :initial_backoff, 10)
    Application.put_env(:anova_manager, :max_backoff, 50)
    :ok
  end

  test "auto-connects with env token and flushes queued commands" do
    System.put_env("token", "test-token")
    Application.put_env(:anova_manager, :ws_module, TestWsSuccess)
    Application.put_env(:anova_manager, :test_pid, self())

    # tell the running GenServer to attempt auto-connect using the env token
    send(AnovaManager.SousVide, {:auto_connect, "test-token"})

    payload = %{cookerId: "abc", type: "APC"}
    :ok = AnovaManager.SousVide.start_cooking(payload)

    # expect TestWsSuccess to send us the sent_frame message when send_frame is called
    assert_receive {:sent_frame, {:text, message}}, 200
    assert message =~ "CMD_APC_START"

    System.delete_env("token")
  end

  test "logs failures and keeps trying until succeed" do
    # seq agent controls behavior: first call fails, second succeeds
    {:ok, _} = Agent.start_link(fn -> [:error, :ok] end, name: :ws_seq)
    Application.put_env(:anova_manager, :ws_module, TestWsSeq)
    Application.put_env(:anova_manager, :test_pid, self())

    log = capture_log(fn ->
      {:error, _} = AnovaManager.SousVide.connect("tok")

      # trigger reconnect to force another start_link attempt (we set small backoff)
      AnovaManager.SousVide.trigger_reconnect()

      # wait a short bit for the second attempt to complete
      :timer.sleep(50)
    end)

    assert log =~ "Failed to start WebSocket"

    # Wait for successful second connect; TestWsSeq will send :connected message
    assert_receive :connected, 200
  end
end

# test helpers

defmodule TestWsSuccess do
  def start_link(_uri, _handler, state) do
    parent = Map.get(state, :parent)
    pid = spawn_link(fn -> receive do :stop -> :ok end end)
    if parent, do: send(parent, {:ws_connected, pid})
    {:ok, pid}
  end

  def send_frame(_pid, frame) do
    test_pid = Application.get_env(:anova_manager, :test_pid)
    if test_pid, do: send(test_pid, {:sent_frame, frame})
    :ok
  end

  def cast(pid, msg), do: send(pid, msg)
end

defmodule TestWsSeq do
  def start_link(_uri, _handler, state) do
    case Agent.get_and_update(:ws_seq, fn
           [h | t] -> {h, t}
           [] -> {:ok, []}
         end) do
      :error ->
        {:error, :econnrefused}

      :ok ->
        parent = Map.get(state, :parent)
        pid = spawn_link(fn -> receive do :stop -> :ok end end)
        if parent, do: send(parent, {:ws_connected, pid})
        # notify test process
        test_pid = Application.get_env(:anova_manager, :test_pid)
        if test_pid, do: send(test_pid, :connected)
        {:ok, pid}
    end
  end

  def send_frame(_pid, frame) do
    test_pid = Application.get_env(:anova_manager, :test_pid)
    if test_pid, do: send(test_pid, {:sent_frame, frame})
    :ok
  end

  def cast(pid, msg), do: send(pid, msg)
end
