defmodule LanShare.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:lan_share, :port, 10086)
    local_ip = LanShare.local_ip()

    children = [
      # 设备注册表 - 跟踪在线设备
      LanShare.DeviceRegistry,
      # 消息历史 - 保留最近消息供新设备加入时查看
      LanShare.MessageStore,
      # HTTP 服务器
      {Plug.Cowboy,
       scheme: :http,
       plug: LanShare.Router,
       options: [port: port, dispatch: dispatch()]}
    ]

    Logger.info("LanShare 启动于 http://0.0.0.0:#{port}")
    Logger.info("局域网内其他设备请访问 http://#{local_ip}:#{port}")

    opts = [strategy: :one_for_one, name: LanShare.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # 自定义 dispatch 以支持 WebSocket 路由
  defp dispatch do
    [
      {:_,
       [
         {"/ws", LanShare.WebSocket, []},
         {:_, Plug.Cowboy.Handler, {LanShare.Router, []}}
       ]}
    ]
  end
end
