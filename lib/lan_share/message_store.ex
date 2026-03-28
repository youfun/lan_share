defmodule LanShare.MessageStore do
  @moduledoc """
  保留最近的消息历史，供新加入的设备查看。
  使用固定大小的环形缓冲区，默认每个房间保留最近 100 条。
  """
  use GenServer

  @max_messages 100

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "添加一条消息到历史"
  def push(room_code, message) do
    GenServer.cast(__MODULE__, {:push, room_code, message})
  end

  @doc "获取所有历史消息"
  def get_history(room_code) do
    GenServer.call(__MODULE__, {:get_history, room_code})
  end

  # --- 回调 ---

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:push, room_code, message}, state) do
    messages =
      state
      |> Map.get(room_code, [])
      |> then(&[message | &1])
      |> Enum.take(@max_messages)

    {:noreply, Map.put(state, room_code, messages)}
  end

  @impl true
  def handle_call({:get_history, room_code}, _from, state) do
    history = state |> Map.get(room_code, []) |> Enum.reverse()
    {:reply, history, state}
  end
end
