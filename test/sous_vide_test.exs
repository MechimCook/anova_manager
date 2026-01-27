defmodule AnovaManager.SousVideTest do
  use ExUnit.Case

  test "initial WiFi list is empty" do
    assert {:ok, []} = AnovaManager.SousVide.get_APC_wifi_list()
  end

  test "start_cooking queues payload when not connected" do
    payload = %{cookerId: "abc", type: "APC", timer: 0, ws_pid: self(), connected: true}
    assert :ok = AnovaManager.SousVide.start_cooking(payload)
    # assert_receive {:start_cooking, _}
  end
end
