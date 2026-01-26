defmodule AnovaManagerWeb.StatusRenderTest do
  use ExUnit.Case
  use Plug.Test

  test "status HTML renders even when no last_apc_state is present" do
    # ensure SousVide has no last state
    # disconnect to make sure it's in a clean state
    AnovaManager.SousVide.disconnect()

    conn = conn(:get, "/status_html") |> AnovaManagerWeb.Router.call([])

    assert conn.status == 200
    assert conn.resp_body =~ "SousVide Status"
    # Should show idle/default values, and not crash
    assert conn.resp_body =~ "job:"
    assert conn.resp_body =~ "temp:"
  end
end
