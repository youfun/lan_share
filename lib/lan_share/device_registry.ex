defmodule LanShare.DeviceRegistry do
  @moduledoc """
  跟踪当前在线的设备。
  每个 WebSocket 连接注册为一个设备,按房间隔离,断开时自动移除。

  房间元数据:
  - 创建者: 第一位注册的设备名,离线后仍保留
  - 模式: `:lan` 或 `:relay`,由第一位进入房间的设备决定,离线后保留

  每条注册同时分配一个稳定的 `peer_id` (UUID),供前端 WebRTC 信令使用。
  """
  use GenServer

  @default_mode :lan

  # --- 公共 API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, initial_state(), name: __MODULE__)
  end

  @doc """
  注册设备。第一位进入房间时,`mode` 决定房间模式;后续设备的 `mode` 参数被忽略。
  返回 `{:ok, peer_id, mode}`,其中 `peer_id` 是本次连接的稳定 ID,`mode` 是房间最终模式。
  """
  def register(pid, device_name, room_code, mode \\ @default_mode) do
    GenServer.call(__MODULE__, {:register, pid, device_name, room_code, mode})
  end

  @doc "注销设备"
  def unregister(pid) do
    GenServer.call(__MODULE__, {:unregister, pid})
  end

  @doc "获取指定房间的在线设备名列表"
  def list_devices(room_code \\ nil) do
    GenServer.call(__MODULE__, {:list_devices, room_code})
  end

  @doc "获取指定房间的在线 peer 列表,返回 `[%{id: peer_id, name: device_name}]`"
  def list_peers(room_code \\ nil) do
    GenServer.call(__MODULE__, {:list_peers, room_code})
  end

  @doc "返回指定房间的创建者设备名,未知房间返回 nil"
  def room_creator(room_code) do
    GenServer.call(__MODULE__, {:room_creator, room_code})
  end

  @doc "返回指定房间的模式 `:lan` 或 `:relay`,未知房间返回默认模式"
  def room_mode(room_code) do
    GenServer.call(__MODULE__, {:room_mode, room_code})
  end

  @doc "根据 peer_id 查找指定房间内对应的进程 pid,未命中返回 nil"
  def peer_pid(room_code, peer_id) do
    GenServer.call(__MODULE__, {:peer_pid, room_code, peer_id})
  end

  @doc "向房间内在线设备广播消息"
  def broadcast(room_code, message, exclude_pid \\ nil) do
    GenServer.cast(__MODULE__, {:broadcast, room_code, message, exclude_pid})
  end

  @doc "向特定 pid 直接发送一条消息(已编码为 JSON)"
  def send_to(pid, message) do
    encoded = Jason.encode!(message)
    send(pid, {:broadcast, encoded})
    :ok
  end

  @doc "清空所有设备及房间元数据(仅供测试)"
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # --- 回调 ---

  @impl true
  def init(_) do
    {:ok, initial_state()}
  end

  @impl true
  def handle_call({:register, pid, device_name, room_code, mode}, _from, state) do
    Process.monitor(pid)
    peer_id = generate_peer_id()

    devices =
      Map.put(state.devices, pid, %{peer_id: peer_id, name: device_name, room_code: room_code})

    rooms =
      Map.update(
        state.rooms,
        room_code,
        %{creator: device_name, mode: mode},
        fn existing -> existing end
      )

    final_mode = rooms[room_code].mode
    {:reply, {:ok, peer_id, final_mode}, %{state | devices: devices, rooms: rooms}}
  end

  @impl true
  def handle_call({:unregister, pid}, _from, state) do
    {:reply, :ok, %{state | devices: Map.delete(state.devices, pid)}}
  end

  @impl true
  def handle_call({:list_devices, room_code}, _from, state) do
    {:reply, list_device_names(state.devices, room_code), state}
  end

  @impl true
  def handle_call({:list_peers, room_code}, _from, state) do
    {:reply, list_peer_descriptors(state.devices, room_code), state}
  end

  @impl true
  def handle_call({:room_creator, room_code}, _from, state) do
    {:reply, room_field(state.rooms, room_code, :creator, nil), state}
  end

  @impl true
  def handle_call({:room_mode, room_code}, _from, state) do
    {:reply, room_field(state.rooms, room_code, :mode, @default_mode), state}
  end

  @impl true
  def handle_call({:peer_pid, room_code, peer_id}, _from, state) do
    pid =
      Enum.find_value(state.devices, fn {pid, device} ->
        if device.room_code == room_code and device.peer_id == peer_id, do: pid
      end)

    {:reply, pid, state}
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
    device = Map.get(state.devices, pid, %{peer_id: nil, name: "未知设备", room_code: nil})
    devices = Map.delete(state.devices, pid)

    leave_msg = %{
      type: "system",
      content: "#{device.name} 已离线",
      devices: list_device_names(devices, device.room_code),
      peers: list_peer_descriptors(devices, device.room_code),
      peer_id: device.peer_id,
      event: "leave"
    }

    encoded = Jason.encode!(leave_msg)

    for {peer_pid, current_device} <- devices, current_device.room_code == device.room_code do
      send(peer_pid, {:broadcast, encoded})
    end

    {:noreply, %{state | devices: devices}}
  end

  defp initial_state, do: %{devices: %{}, rooms: %{}}

  defp list_device_names(devices, room_code) do
    devices
    |> Enum.filter(fn {_pid, device} -> device.room_code == room_code end)
    |> Enum.map(fn {_pid, device} -> device.name end)
    |> Enum.sort()
  end

  defp list_peer_descriptors(devices, room_code) do
    devices
    |> Enum.filter(fn {_pid, device} -> device.room_code == room_code end)
    |> Enum.map(fn {_pid, device} -> %{id: device.peer_id, name: device.name} end)
    |> Enum.sort_by(& &1.name)
  end

  defp room_field(rooms, room_code, field, default) do
    case Map.get(rooms, room_code) do
      nil -> default
      room -> Map.get(room, field, default)
    end
  end

  defp generate_peer_id do
    Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end
end
