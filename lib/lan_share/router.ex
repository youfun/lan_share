defmodule LanShare.Router do
  @moduledoc """
  HTTP 路由。
  - GET /        → 主页面 (单页应用)
  - GET /r/:code → 房间页面
  - POST /join   → 加入房间
  - POST /upload → 图片上传 (备用 HTTP 上传通道)
  - GET /api/devices → 在线设备列表
  """
  use Plug.Router

  import Plug.Conn

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    # 最大 20MB 上传
    length: 20_000_000
  )

  plug(:dispatch)

  # 主页面
  get "/" do
    html = LanShare.Page.render(nil)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/r/:code" do
    case LanShare.Room.normalize(code) do
      nil ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "无效房间码")

      room_code ->
        html = LanShare.Page.render(room_code)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)
    end
  end

  get "/r/:code/qrcode.svg" do
    case LanShare.Room.normalize(code) do
      nil ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "无效房间码")

      room_code ->
        room_url = absolute_room_url(conn, room_code)

        case LanShare.RoomQRCode.svg(room_url) do
          {:ok, svg} ->
            conn
            |> put_resp_content_type("image/svg+xml")
            |> send_resp(200, svg)

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(500, Jason.encode!(%{error: reason}))
        end
    end
  end

  get "/room/new" do
    conn
    |> put_resp_header("location", LanShare.Room.path(LanShare.Room.generate()))
    |> send_resp(302, "")
  end

  post "/join" do
    case LanShare.Room.normalize(conn.params["code"]) do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "房间码必须为 4 位字母或数字"}))

      room_code ->
        conn
        |> put_resp_header("location", LanShare.Room.path(room_code))
        |> send_resp(302, "")
    end
  end

  # 在线设备 API
  get "/api/devices" do
    devices = LanShare.DeviceRegistry.list_devices(LanShare.Room.normalize(conn.params["room"]))

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

  defp absolute_room_url(conn, room_code) do
    scheme = Atom.to_string(conn.scheme)
    host = conn.host
    port = conn.port
    default_port? = (scheme == "http" and port == 80) or (scheme == "https" and port == 443)
    authority = if default_port?, do: host, else: "#{host}:#{port}"

    scheme <> "://" <> authority <> LanShare.Room.path(room_code)
  end
end
