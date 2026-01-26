defmodule AnovaManagerWeb.Pages.Home do
  @moduledoc "Simple home page HTML renderer for the scheduling form."

  def render do
    """
    <html><body>
    <h1>AnovaManager</h1>
    <p><a href="/status">View SousVide status (JSON)</a> | <a href="/status_html">View status (HTML)</a></p>
    <form action="/schedule" method="POST">
      Cooker ID: <input name="cookerId" /> <br />
      Type: <input name="type" value="APC" /> <br />
      Target Temp: <input name="targetTemperature" /> <br />
      Timer (min): <input name="timer" /> <br />
      Delay (sec): <input name="delay" value="0" /> <br />
      Queue only: <input type="checkbox" name="queue" value="true" /> <br />
      <button type="submit">Schedule</button>
    </form>
    </body></html>
    """
  end
end
