defmodule LanShare.WebSocket do
  @moduledoc """
  Cowboy WebSocket handler。
  处理实时消息收发、设备上下线通知，并按房间隔离。
  """
  @behaviour :cowboy_websocket
  @max_inline_image_size 5 * 1024 * 1024

  @impl true
  def init(req, _state) do
    # 从请求头提取 User-Agent
    ua = :cowboy_req.header("user-agent", req, "")
    device_name = LanShare.UAParser.parse(ua)
    room_code = extract_room_code(req)

    # 用 peer IP 加设备名去重
    {ip, _port} = :cowboy_req.peer(req)
    ip_str = ip |> :inet.ntoa() |> to_string()

    state = %{
      device_name: format_device_name(device_name, ip_str),
      ip: ip_str,
      room_code: room_code
    }

    {:cowboy_websocket, req, state}
  end

  @impl true
  def websocket_init(state) do
    # 注册到设备列表
    LanShare.DeviceRegistry.register(self(), state.device_name, state.room_code)

    # 发送历史消息
    history = LanShare.MessageStore.get_history(state.room_code)
    history_msg = Jason.encode!(%{type: "history", messages: history})

    welcome_msg =
      Jason.encode!(%{
        type: "welcome",
        device_name: state.device_name,
        devices: LanShare.DeviceRegistry.list_devices(state.room_code),
        room_code: state.room_code,
        room_label: LanShare.Room.label(state.room_code)
      })

    # 获取当前在线设备并广播
    devices = LanShare.DeviceRegistry.list_devices(state.room_code)

    join_msg = %{
      type: "system",
      content: "#{state.device_name} 已加入",
      devices: devices,
      room_code: state.room_code
    }

    LanShare.DeviceRegistry.broadcast(state.room_code, join_msg)

    {[{:text, welcome_msg}, {:text, history_msg}], state}
  end

  @impl true
  def websocket_handle({:text, raw}, state) do
    case Jason.decode(raw) do
      {:ok, %{"type" => "text", "content" => content}} ->
        text = content

        if String.trim(text) == "" do
          {:ok, state}
        else
          msg = %{
            type: "text",
            sender: state.device_name,
            content: text,
            content_html: LanShare.Markdown.render(text),
            timestamp: now_iso(),
            room_code: state.room_code
          }

          LanShare.MessageStore.push(state.room_code, msg)
          LanShare.DeviceRegistry.broadcast(state.room_code, msg)
          {:ok, state}
        end

      {:ok, %{"type" => "image", "data" => data, "filename" => filename}} ->
        if valid_inline_image?(data) do
          msg = %{
            type: "image",
            sender: state.device_name,
            data: data,
            filename: sanitize_filename(filename),
            timestamp: now_iso(),
            room_code: state.room_code
          }

          LanShare.MessageStore.push(state.room_code, msg)
          LanShare.DeviceRegistry.broadcast(state.room_code, msg)
        end

        {:ok, state}

      {:ok, %{"type" => "ping"}} ->
        pong = Jason.encode!(%{type: "pong"})
        {[{:text, pong}], state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  @impl true
  def websocket_info({:broadcast, encoded_msg}, state) do
    {[{:text, encoded_msg}], state}
  end

  @impl true
  def websocket_info(_info, state) do
    {:ok, state}
  end

  defp now_iso do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp format_device_name(device_name, ip_str) do
    suffix = ip_str |> String.split(".") |> List.last()
    "#{device_name} · #{suffix}"
  end

  defp extract_room_code(req) do
    req
    |> :cowboy_req.parse_qs()
    |> Enum.find_value(fn
      {"room", value} -> LanShare.Room.normalize(value)
      _ -> nil
    end)
  end

  defp valid_inline_image?("data:image/" <> _rest = data) do
    byte_size(data) <= @max_inline_image_size * 2
  end

  defp valid_inline_image?(_), do: false

  defp sanitize_filename(filename) when is_binary(filename) and filename != "" do
    Path.basename(filename)
  end

  defp sanitize_filename(_), do: "image"
end
