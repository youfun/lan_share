defmodule LanShare.Router do
  @moduledoc """
  HTTP 路由。
  - GET /        → 主页面 (单页应用)
  - GET /r/:code → 房间页面
  - POST /join   → 加入房间
  - POST /upload → 图片上传 (备用 HTTP 上传通道)
  - POST /upload/file → 通用文件上传
  - GET /files/:id → 房间文件下载
  - GET /api/devices → 在线设备列表
  """
  use Plug.Router
  use Plug.ErrorHandler

  import Plug.Conn

  @max_upload_length LanShare.FileStore.max_file_size()

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    # 最大 1GB 上传
    length: @max_upload_length
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

  post "/upload/file" do
    with {:ok, room_code} <- normalize_room_param(conn.params["room"]),
         {:ok, upload} <- fetch_upload(conn.params["file"]),
         {:ok, metadata} <- LanShare.FileStore.store_upload(upload, room_code) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(metadata))
    else
      {:error, :invalid_room} ->
        send_json_error(conn, 400, "房间码必须为 4 位字母或数字")

      {:error, :missing_file} ->
        send_json_error(conn, 400, "未找到文件")

      {:error, :file_too_large} ->
        send_json_error(conn, 413, "文件大小不能超过 1GB")

      {:error, :insufficient_disk_space} ->
        send_json_error(conn, 507, "磁盘剩余空间不足")

      {:error, _reason} ->
        send_json_error(conn, 500, "文件上传失败")
    end
  end

  get "/files/:id" do
    with {:ok, requested_room} <- normalize_room_param(conn.params["room"]),
         {:ok, metadata} <- lookup_file(id),
         :ok <- authorize_room_access(metadata.room_code, requested_room),
         :ok <- ensure_file_exists(metadata.path) do
      send_file_download(conn, metadata)
    else
      {:error, :invalid_room} ->
        send_json_error(conn, 400, "房间码必须为 4 位字母或数字")

      {:error, :room_mismatch} ->
        send_json_error(conn, 403, "无权访问该文件")

      {:error, :not_found} ->
        send_json_error(conn, 404, "文件不存在")
    end
  end

  # 404
  match _ do
    send_resp(conn, 404, "Not Found")
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{reason: %Plug.Parsers.RequestTooLargeError{}}) do
    send_json_error(conn, 413, "文件大小不能超过 1GB")
  end

  def handle_errors(conn, _error) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(conn.status || 500, "服务器错误")
  end

  defp absolute_room_url(conn, room_code) do
    scheme = Atom.to_string(conn.scheme)
    host = conn.host
    port = conn.port
    default_port? = (scheme == "http" and port == 80) or (scheme == "https" and port == 443)
    authority = if default_port?, do: host, else: "#{host}:#{port}"

    scheme <> "://" <> authority <> LanShare.Room.path(room_code)
  end

  defp normalize_room_param(room_param) do
    case LanShare.Room.normalize(room_param) do
      nil -> {:error, :invalid_room}
      room_code -> {:ok, room_code}
    end
  end

  defp fetch_upload(%Plug.Upload{} = upload), do: {:ok, upload}
  defp fetch_upload(_value), do: {:error, :missing_file}

  defp lookup_file(id) do
    case LanShare.FileStore.lookup(id) do
      {:ok, metadata} -> {:ok, metadata}
      :error -> {:error, :not_found}
    end
  end

  defp authorize_room_access(expected_room, expected_room), do: :ok
  defp authorize_room_access(_expected_room, _requested_room), do: {:error, :room_mismatch}

  defp ensure_file_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, :not_found}
  end

  defp send_json_error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
  end

  defp send_file_download(conn, metadata) do
    conn
    |> put_resp_content_type(metadata.content_type)
    |> put_resp_header("content-disposition", attachment_header(metadata.filename))
    |> send_file(200, metadata.path)
  end

  defp attachment_header(filename) do
    escaped_filename = String.replace(filename, "\"", "\\\"")
    encoded_filename = URI.encode(filename)
    "attachment; filename=\"#{escaped_filename}\"; filename*=UTF-8''#{encoded_filename}"
  end
end
