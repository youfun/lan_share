defmodule LanShare.DeviceRegistry do
  @moduledoc """
  跟踪当前在线的设备。
  每个 WebSocket 连接注册为一个设备，断开时自动移除。
  """
  use GenServer

  # --- 公共 API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "注册设备，pid 为 WebSocket 进程"
  def register(pid, device_name) do
    GenServer.call(__MODULE__, {:register, pid, device_name})
  end

  @doc "注销设备"
  def unregister(pid) do
    GenServer.call(__MODULE__, {:unregister, pid})
  end

  @doc "获取所有在线设备列表 [{pid, device_name}]"
  def list_devices do
    GenServer.call(__MODULE__, :list)
  end

  @doc "向所有在线设备广播消息"
  def broadcast(message) do
    GenServer.cast(__MODULE__, {:broadcast, message})
  end

  @doc "向除 sender 外的所有设备广播"
  def broadcast(message, exclude_pid) do
    GenServer.cast(__MODULE__, {:broadcast, message, exclude_pid})
  end

  # --- 回调 ---

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, pid, device_name}, _from, devices) do
    Process.monitor(pid)
    devices = Map.put(devices, pid, device_name)
    {:reply, :ok, devices}
  end

  @impl true
  def handle_call({:unregister, pid}, _from, devices) do
    devices = Map.delete(devices, pid)
    {:reply, :ok, devices}
  end

  @impl true
  def handle_call(:list, _from, devices) do
    list = Enum.map(devices, fn {_pid, name} -> name end)
    {:reply, list, devices}
  end

  @impl true
  def handle_cast({:broadcast, message}, devices) do
    encoded = Jason.encode!(message)
    for {pid, _name} <- devices do
      send(pid, {:broadcast, encoded})
    end
    {:noreply, devices}
  end

  @impl true
  def handle_cast({:broadcast, message, exclude_pid}, devices) do
    encoded = Jason.encode!(message)
    for {pid, _name} <- devices, pid != exclude_pid do
      send(pid, {:broadcast, encoded})
    end
    {:noreply, devices}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, devices) do
    device_name = Map.get(devices, pid, "未知设备")
    devices = Map.delete(devices, pid)

    # 广播设备离线通知
    leave_msg = %{
      type: "system",
      content: "#{device_name} 已离线",
      devices: Enum.map(devices, fn {_p, n} -> n end)
    }

    encoded = Jason.encode!(leave_msg)
    for {p, _n} <- devices do
      send(p, {:broadcast, encoded})
    end

    {:noreply, devices}
  end
end
