defmodule AnovaManagerWeb.Router do
  use Plug.Router
  use Plug.Debugger

  plug(:match)
  plug(:dispatch)

  get "/" do
    body = AnovaManagerWeb.Pages.Home.render()
    send_resp(conn, 200, body)
  end

  get "/status" do
    status = AnovaManager.SousVide.status()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end

  get "/status_html" do
    status = AnovaManager.SousVide.status()
    body = AnovaManagerWeb.Pages.Status.render(status)
    send_resp(conn, 200, body)
  end

  post "/schedule" do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    params = Plug.Conn.Query.decode(body)

    cooker_id = Map.get(params, "cookerId")
    type = Map.get(params, "type", "a4")
    target_temp = Map.get(params, "targetTemperature")
    timer = Map.get(params, "timer")
    delay = Map.get(params, "delay", "0") |> String.to_integer()

    payload =
      %{unit: "F"}
      |> Map.merge(if cooker_id, do: %{cookerId: cooker_id}, else: %{})
      |> Map.merge(if type, do: %{type: type}, else: %{})
      |> Map.merge(
        if target_temp in [nil, ""],
          do: %{},
          else: %{targetTemperature: String.to_integer(target_temp)}
      )
      |> Map.merge(if timer in [nil, ""], do: %{}, else: %{timer: String.to_integer(timer)})

    if delay > 0 do
      # schedule delayed job in a separate process so it will call SousVide.start_cooking later
      Task.start(fn ->
        :timer.sleep(delay * 1_000)
        AnovaManager.SousVide.enqueue(payload)
      end)

      send_resp(conn, 200, "Scheduled job in #{delay} seconds")
    else
      # immediate
      AnovaManager.SousVide.start_cooking(payload)
      send_resp(conn, 200, "Scheduled immediate job")
    end
  end

  # internal helper when running under Plug.Cowboy; this won't be invoked in tests
  def child_spec(_opts) do
    Plug.Cowboy.child_spec(scheme: :http, plug: __MODULE__, options: [port: 4001])
  end
end
