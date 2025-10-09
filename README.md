# AnovaManager

**TODO: Setup cloudflare**
**TODO: Setup NGROX**
**TODO: keep warm mode**
**TODO: Setup jobs**
**TODO: Manual interface**
**TODO: Recipe listings**
**TODO: Recipe start option**

## Installation

```elixir
def deps do
  [
    {:anova_manager, "~> 0.1.0"}
  ]
end
```

examples for websocket

```elixir
{:ok, pid} = AnovaWebSocket.connect(token)
{:ok,
 [
   %{
     "cookerId" => cookerId,
     "type" => type
   }
 ]} = AnovaWebSocket.get_APC_wifi_list()
AnovaWebSocket.start_cooking(%{cookerId: cookerId, type: type, unit: "F", targetTemperature: 135, timer: 60})
AnovaWebSocket.stop_cooking(%{cookerId: cookerId, type: type})
```

error modes
"LOW WATER"
"DEVICE FAILURE"