defmodule AnovaManager.SousVideTest do
  use ExUnit.Case

  test "initial WiFi list is empty" do
    assert {:ok, []} = AnovaManager.SousVide.get_APC_wifi_list()
  end

  test "start_cooking queues payload when not connected" do
    payload = %{cookerId: "abc", type: "APC"}
    assert {:queued, ^payload} = AnovaManager.SousVide.start_cooking(payload)
  end
end
