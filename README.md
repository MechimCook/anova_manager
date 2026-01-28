# AnovaManager

**TODO: Setup cloudflare**
**TODO: Setup NGROX**
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
{:ok, pid} = AnovaManager.SousVide.connect(token)
{:ok,
 [
   %{
     "cookerId" => cookerId,
     "type" => type
   }
 ]} = AnovaManager.SousVide.get_APC_wifi_list()
AnovaManager.SousVide.start_cooking(%{cookerId: cookerId, type: type, unit: "F", targetTemperature: 135, timer: 60})
AnovaManager.SousVide.stop_cooking(%{cookerId: cookerId, type: type})
```

error modes
"LOW WATER"
"DEVICE FAILURE"