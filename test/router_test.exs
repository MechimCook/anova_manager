defmodule AnovaManagerWeb.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  setup do
    # speed up backoffs and inject test WS
    Application.put_env(:anova_manager, :initial_backoff, 10)
    Application.put_env(:anova_manager, :ws_module, AnovaManagerWeb.RouterTest.TestWsLocal)
    Application.put_env(:anova_manager, :test_pid, self())

    # ensure the supervised SousVide instance connects so tests see send_frame calls
    {:ok, _pid} = AnovaManager.SousVide.connect("tok")

    :ok
  end

  # local test WS implementation used only by router tests
  defmodule TestWsLocal do
    def start_link(_uri, _handler, state) do
      parent = Map.get(state, :parent)

      pid =
        spawn_link(fn ->
          receive do
            :stop -> :ok
          end
        end)

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

  test "GET / returns form" do
    conn = conn(:get, "/") |> AnovaManagerWeb.Router.call([])
    assert conn.status == 200
    assert conn.resp_body =~ "Schedule"
    assert conn.resp_body =~ "/status"
  end

  test "GET /status returns JSON status" do
    conn = conn(:get, "/status") |> AnovaManagerWeb.Router.call([])
    assert conn.status == 200

    assert List.first(get_resp_header(conn, "content-type"))
           |> String.starts_with?("application/json")

    body = Jason.decode!(conn.resp_body)
    assert Map.has_key?(body, "connected")
    assert is_list(body["queue"]) or is_list(body["queue"]) == true
  end

  test "GET /status_html returns HTML page with status info" do
    conn = conn(:get, "/status_html") |> AnovaManagerWeb.Router.call([])
    assert conn.status == 200
    assert conn.resp_body =~ "SousVide Status"
  end

  test "POST /schedule immediate triggers a cook" do
    body = Plug.Conn.Query.encode(%{"cookerId" => "abc", "type" => "APC", "timer" => "0"})
    conn = conn(:post, "/schedule", body)
    conn = put_req_header(conn, "content-type", "application/x-www-form-urlencoded")
    conn = AnovaManagerWeb.Router.call(conn, [])

    assert conn.status == 200
    assert conn.resp_body =~ "immediate"

    # expect the TestWsSuccess send_frame to be invoked
    assert_receive {:sent_frame, {:text, message}}, 100
    assert message =~ "CMD_APC_START"
  end

  test "POST /schedule delayed triggers after delay" do
    body = Plug.Conn.Query.encode(%{"cookerId" => "abc", "type" => "APC", "delay" => "1"})
    conn = conn(:post, "/schedule", body)
    conn = put_req_header(conn, "content-type", "application/x-www-form-urlencoded")
    conn = AnovaManagerWeb.Router.call(conn, [])

    assert conn.status == 200
    assert conn.resp_body =~ "Scheduled job in 1 seconds"
  end
end
