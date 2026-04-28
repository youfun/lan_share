defmodule LanShare.DeviceRegistry do
  @moduledoc """
  跟踪当前在线的设备。
  每个 WebSocket 连接注册为一个设备，按房间隔离，断开时自动移除。
  同时记录每个房间的创建者：第一位注册的设备名，离线后仍保留。
  """
  use GenServer

  # --- 公共 API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, initial_state(), name: __MODULE__)
  end

  @doc "注册设备，pid 为 WebSocket 进程"
  def register(pid, device_name, room_code) do
    GenServer.call(__MODULE__, {:register, pid, device_name, room_code})
  end

  @doc "注销设备"
  def unregister(pid) do
    GenServer.call(__MODULE__, {:unregister, pid})
  end

  @doc "获取指定房间的在线设备名列表"
  def list_devices(room_code \\ nil) do
    GenServer.call(__MODULE__, {:list, room_code})
  end

  @doc """
  返回指定房间的创建者设备名，未知房间返回 nil。
  注：身份基于 UA + IP 末段，换设备/换网络后会变成不同 device_name。
  """
  def room_creator(room_code) do
    GenServer.call(__MODULE__, {:room_creator, room_code})
  end

  @doc "向房间内在线设备广播消息"
  def broadcast(room_code, message, exclude_pid \\ nil) do
    GenServer.cast(__MODULE__, {:broadcast, room_code, message, exclude_pid})
  end

  @doc "清空所有设备及房间创建者记录（仅供测试）"
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # --- 回调 ---

  @impl true
  def init(_) do
    {:ok, initial_state()}
  end

  @impl true
  def handle_call({:register, pid, device_name, room_code}, _from, state) do
    Process.monitor(pid)
    devices = Map.put(state.devices, pid, %{name: device_name, room_code: room_code})

    creators =
      Map.put_new(state.creators, room_code, device_name)

    {:reply, :ok, %{state | devices: devices, creators: creators}}
  end

  @impl true
  def handle_call({:unregister, pid}, _from, state) do
    {:reply, :ok, %{state | devices: Map.delete(state.devices, pid)}}
  end

  @impl true
  def handle_call({:list, room_code}, _from, state) do
    {:reply, list_device_names(state.devices, room_code), state}
  end

  @impl true
  def handle_call({:room_creator, room_code}, _from, state) do
    {:reply, Map.get(state.creators, room_code), state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, initial_state()}
  end

  @impl true
  def handle_cast({:broadcast, room_code, message, exclude_pid}, state) do
    encoded = Jason.encode!(message)

    for {pid, device} <- state.devices,
        device.room_code == room_code,
        is_nil(exclude_pid) or pid != exclude_pid do
      send(pid, {:broadcast, encoded})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    device = Map.get(state.devices, pid, %{name: "未知设备", room_code: nil})
    devices = Map.delete(state.devices, pid)

    leave_msg = %{
      type: "system",
      content: "#{device.name} 已离线",
      devices: list_device_names(devices, device.room_code)
    }

    encoded = Jason.encode!(leave_msg)

    for {peer_pid, current_device} <- devices, current_device.room_code == device.room_code do
      send(peer_pid, {:broadcast, encoded})
    end

    {:noreply, %{state | devices: devices}}
  end

  defp initial_state, do: %{devices: %{}, creators: %{}}

  defp list_device_names(devices, room_code) do
    devices
    |> Enum.filter(fn {_pid, device} -> device.room_code == room_code end)
    |> Enum.map(fn {_pid, device} -> device.name end)
    |> Enum.sort()
  end
end
