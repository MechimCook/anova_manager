defmodule TestWsSuccess do
  def start_link(_uri, _handler, state) do
    parent = Map.get(state, :parent)
    pid = spawn_link(fn -> receive do :stop -> :ok end end)
    if parent, do: send(parent, {:ws_connected, pid})
    # notify test process
    test_pid = Application.get_env(:anova_manager, :test_pid)
    if test_pid, do: send(test_pid, :connected)
    {:ok, pid}
  end

  def send_frame(_pid, frame) do
    test_pid = Application.get_env(:anova_manager, :test_pid)
    if test_pid, do: send(test_pid, {:sent_frame, frame})
    :ok
  end

  def cast(pid, msg), do: send(pid, msg)
end

defmodule TestWsSeq do
  def start_link(_uri, _handler, state) do
    case Agent.get_and_update(:ws_seq, fn
           [h | t] -> {h, t}
           [] -> {:ok, []}
         end) do
      :error ->
        {:error, :econnrefused}

      :ok ->
        parent = Map.get(state, :parent)
        pid = spawn_link(fn -> receive do :stop -> :ok end end)
        if parent, do: send(parent, {:ws_connected, pid})
        # notify test process
        test_pid = Application.get_env(:anova_manager, :test_pid)
        if test_pid, do: send(test_pid, :connected)
        {:ok, pid}
    end
  end

  def send_frame(_pid, frame) do
    test_pid = Application.get_env(:anova_manager, :test_pid)
    if test_pid, do: send(test_pid, {:sent_frame, frame})
    :ok
  end

  def cast(pid, msg), do: send(pid, msg)
end
