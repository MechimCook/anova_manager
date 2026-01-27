defmodule AnovaManager.SousVideStateTest do
  use ExUnit.Case, async: false

  setup do
    # ensure we use a simple test ws that doesn't try to connect to the real service
    Application.put_env(:anova_manager, :ws_module, TestWsSuccess)
    Application.put_env(:anova_manager, :test_pid, self())

    {:ok, _} = AnovaManager.SousVide.connect("tok")
    :ok
  end

  test "EVENT_APC_STATE updates last_apc_state and is visible in status" do
    msg = %{"command" => "EVENT_APC_STATE", "payload" => %{"state" => %{"id" => "dev1", "pin-info" => %{"p" => 1}}}}

    send(AnovaManager.SousVide, {:ws_message, msg})
    # allow the GenServer to process
    :timer.sleep(10)

    status = AnovaManager.SousVide.status()
    assert status[:last_apc_state] == msg["payload"]
  end
end
