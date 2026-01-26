defmodule AnovaManager.SousVideQueueTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    # ensure a predictable WS module that doesn't auto-connect
    Application.put_env(:anova_manager, :ws_module, TestWsSuccess)
    Application.put_env(:anova_manager, :test_pid, self())

    # ensure disconnected state
    AnovaManager.SousVide.disconnect()

    :ok
  end

  test "scheduling while disconnected adds to queue and is visible in status map" do
    payload = %{cookerId: "q1", type: "APC", timer: 0}

    assert :ok = AnovaManager.SousVide.start_cooking(payload)
    Process.sleep(10)  # allow GenServer to process
    status = AnovaManager.SousVide.status()
    assert is_list(status.queue)
    assert [{:start_cooking,_}|_] = status.queue
  end

  test "HTML status shows queued jobs" do
    payload = %{cookerId: "q2", type: "APC", timer: 0}
    :ok = AnovaManager.SousVide.start_cooking(payload)

    Process.sleep(10)  # allow GenServer to process

    conn = conn(:get, "/status_html") |> AnovaManagerWeb.Router.call([])
    assert conn.status == 200
    assert conn.resp_body =~ "Queue"
    assert conn.resp_body =~ "start_cooking"
    assert conn.resp_body =~ "q2"
  end
end
