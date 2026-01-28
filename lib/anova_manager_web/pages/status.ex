defmodule AnovaManagerWeb.Pages.Status do
  @moduledoc "Simple HTML renderer for SousVide status"

  def render(status) when is_map(status) do
    queue_html =
      case status[:queue] || status["queue"] do
        [] ->
          "<p>No pending jobs</p>"

        q ->
          items =
            Enum.map(q, fn
              %{"type" => t, "payload" => p} -> "<li>#{t}: #{inspect(p)}</li>"
              %{type: t, payload: p} -> "<li>#{t}: #{inspect(p)}</li>"
              {t, p} -> "<li>#{t}: #{inspect(p)}</li>"
              _ -> "<li>unknown</li>"
            end)

          "<ul>" <> Enum.join(items, "") <> "</ul>"
      end

    state = status[:last_apc_state]["state"]

    cooker_status =
      if state do
        temp_info = state["temperature-info"]

        temp =
          if temp_info && temp_info["water-temperature"] do
            temp_info["water-temperature"]
            |> (&(&1 * 9 / 5 + 35)).()
            |> inspect()
          else
            "unknown"
          end

        cookerId = inspect(status[:last_apc_state]["cookerId"])

        """
        <pre>job: #{inspect(state["job"])}</pre>
        <pre>job status: #{inspect(status["job-status"])}</pre>
        <pre>temp: #{temp} F</pre>
        <form action="/schedule" method="POST">
        Cooker ID: <input name="cookerId" value=#{cookerId}/> <br />
        Type: <input name="type" value="a4" /> <br />
        Target Temp: <input name="targetTemperature" /> <br />
        Timer (min): <input name="timer" /> <br />
        Delay (sec): <input name="delay" value="0" /> <br />
        <button type="submit">Schedule</button>
        </form>
        """
      else
        "<pre>no cooker connected</pre>"
      end

    """
    <html><body>
      <h1>SousVide Status</h1>
      #{cooker_status}
      <h2>Queue</h2>
      #{queue_html}
    </body></html>
    """
  end
end
