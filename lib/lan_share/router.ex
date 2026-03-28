defmodule LanShare.Router do
  @moduledoc """
  HTTP 路由。
  - GET /        → 主页面 (单页应用)
  - POST /upload → 图片上传 (备用 HTTP 上传通道)
  - GET /api/devices → 在线设备列表
  """
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: 20_000_000  # 最大 20MB 上传

  plug :dispatch

  # 主页面
  get "/" do
    html = LanShare.Page.render()
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # 在线设备 API
  get "/api/devices" do
    devices = LanShare.DeviceRegistry.list_devices()
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{devices: devices}))
  end

  # 图片上传 (HTTP 方式，供不支持大 base64 WebSocket 的场景)
  post "/upload" do
    case conn.params do
      %{"file" => %Plug.Upload{path: path, filename: filename, content_type: content_type}} ->
        {:ok, data} = File.read(path)
        base64 = Base.encode64(data)
        data_uri = "data:#{content_type};base64,#{base64}"

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{url: data_uri, filename: filename}))

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "未找到文件"}))
    end
  end

  # 404
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
