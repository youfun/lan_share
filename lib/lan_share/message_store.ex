defmodule LanShare.MessageStore do
  @moduledoc """
  保留最近的消息历史，供新加入的设备查看。
  使用固定大小的环形缓冲区，默认保留最近 100 条。
  """
  use GenServer

  @max_messages 100

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "添加一条消息到历史"
  def push(message) do
    GenServer.cast(__MODULE__, {:push, message})
  end

  @doc "获取所有历史消息"
  def get_history do
    GenServer.call(__MODULE__, :get_history)
  end

  # --- 回调 ---

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:push, message}, messages) do
    messages = [message | messages] |> Enum.take(@max_messages)
    {:noreply, messages}
  end

  @impl true
  def handle_call(:get_history, _from, messages) do
    {:reply, Enum.reverse(messages), messages}
  end
end
