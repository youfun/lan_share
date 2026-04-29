defmodule LanShare.WebSocket do
  @moduledoc """
  Cowboy WebSocket handler。
  处理实时消息收发、设备上下线通知,并按房间隔离。

  房间支持两种模式:
  - `:lan` 本机仅作为信令转发器,文本/图片/文件直接走 WebRTC DataChannel,服务器不存不转
  - `:relay` 历史行为,所有内容经服务器转发并持久化
  """
  @behaviour :cowboy_websocket
  @max_inline_image_size 5 * 1024 * 1024
  @lobby_room_code "_LOBBY"

  @impl true
  def init(req, _state) do
    # 从请求头提取 User-Agent
    ua = :cowboy_req.header("user-agent", req, "")
    device_name = LanShare.UAParser.parse(ua)
    {room_code, mode} = extract_room_and_mode(req)

    # 用 peer IP 加设备名去重
    {ip, _port} = :cowboy_req.peer(req)
    ip_str = ip |> :inet.ntoa() |> to_string()

    state = %{
      device_name: format_device_name(device_name, ip_str),
      ip: ip_str,
      room_code: room_code,
      mode_hint: mode,
      mode: mode,
      peer_id: nil
    }

    {:cowboy_websocket, req, state}
  end

  @impl true
  def websocket_init(state) do
    # 注册到设备列表(注册顺序决定 room_creator 与房间模式)
    {:ok, peer_id, mode} =
      LanShare.DeviceRegistry.register(
        self(),
        state.device_name,
        state.room_code,
        state.mode_hint
      )

    state = %{state | peer_id: peer_id, mode: mode}

    # 历史消息: 只有中继模式才返回历史
    history =
      case mode do
        :relay -> LanShare.MessageStore.get_history(state.room_code)
        :lan -> []
      end

    history_msg = Jason.encode!(%{type: "history", messages: history})

    welcome_msg =
      Jason.encode!(%{
        type: "welcome",
        device_name: state.device_name,
        peer_id: peer_id,
        mode: Atom.to_string(mode),
        devices: LanShare.DeviceRegistry.list_devices(state.room_code),
        peers: LanShare.DeviceRegistry.list_peers(state.room_code),
        room_code: state.room_code,
        room_label: LanShare.Room.label(state.room_code),
        room_creator: LanShare.DeviceRegistry.room_creator(state.room_code)
      })

    # 获取当前在线设备并广播 join 事件 (含 peer 信息,供 LAN 模式建立 RTC 连接)
    devices = LanShare.DeviceRegistry.list_devices(state.room_code)
    peers = LanShare.DeviceRegistry.list_peers(state.room_code)

    join_msg = %{
      type: "system",
      content: "#{state.device_name} 已加入",
      devices: devices,
      peers: peers,
      peer_id: peer_id,
      event: "join",
      room_code: state.room_code
    }

    LanShare.DeviceRegistry.broadcast(state.room_code, join_msg)

    {[{:text, welcome_msg}, {:text, history_msg}], state}
  end

  @impl true
  def websocket_handle({:text, raw}, state) do
    case Jason.decode(raw) do
      {:ok, %{"type" => "text", "content" => content}} when state.mode == :relay ->
        text = content

        if String.trim(text) == "" do
          {:ok, state}
        else
          msg = %{
            id: generate_message_id(),
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

      {:ok, %{"type" => "image", "data" => data, "filename" => filename}}
      when state.mode == :relay ->
        if valid_inline_image?(data) do
          msg = %{
            id: generate_message_id(),
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

      {:ok, %{"type" => "file", "id" => file_id}} when state.mode == :relay ->
        case build_file_message(file_id, state) do
          {:ok, msg} ->
            LanShare.MessageStore.push(state.room_code, msg)
            LanShare.DeviceRegistry.broadcast(state.room_code, msg)

          :error ->
            :ok
        end

        {:ok, state}

      {:ok, %{"type" => "delete", "id" => message_id}}
      when is_binary(message_id) and state.mode == :relay ->
        handle_delete(state, message_id)
        {:ok, state}

      {:ok, %{"type" => "signal", "to" => target_peer_id} = msg} when is_binary(target_peer_id) ->
        forward_signal(state, target_peer_id, Map.get(msg, "payload"))
        {:ok, state}

      {:ok, %{"type" => "ping"}} ->
        pong = Jason.encode!(%{type: "pong"})
        {[{:text, pong}], state}

      _ ->
        # LAN 模式下文本/图片/文件被静默忽略,前端应改用 DataChannel
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

  @doc """
  判断给定 device_name 是否有权删除某条消息。
  仅消息发送者本人,或当前房间的创建者,可以删除。
  """
  def authorized_to_delete?(message, device_name, room_creator) do
    sender = Map.get(message, :sender) || Map.get(message, "sender")
    sender == device_name or device_name == room_creator
  end

  defp forward_signal(state, target_peer_id, payload) when payload != nil do
    case LanShare.DeviceRegistry.peer_pid(state.room_code, target_peer_id) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        LanShare.DeviceRegistry.send_to(pid, %{
          type: "signal",
          from: state.peer_id,
          payload: payload
        })
    end
  end

  defp forward_signal(_state, _target, _payload), do: :ok

  defp handle_delete(state, message_id) do
    with {:ok, message} <- LanShare.MessageStore.lookup(state.room_code, message_id),
         room_creator = LanShare.DeviceRegistry.room_creator(state.room_code),
         true <- authorized_to_delete?(message, state.device_name, room_creator) do
      cascade_delete_file(message, state.room_code)

      case LanShare.MessageStore.delete(state.room_code, message_id) do
        {:ok, _msg} ->
          LanShare.DeviceRegistry.broadcast(state.room_code, %{
            type: "deleted",
            id: message_id,
            room_code: state.room_code
          })

        {:error, :not_found} ->
          :ok
      end
    else
      _ -> :ok
    end
  end

  defp cascade_delete_file(%{type: "file", id: file_id}, room_code)
       when is_binary(file_id) do
    file_room = file_room_code(room_code)
    LanShare.FileStore.delete(file_id, file_room)
    :ok
  end

  defp cascade_delete_file(_message, _room_code), do: :ok

  defp file_room_code(nil), do: @lobby_room_code
  defp file_room_code(code) when is_binary(code), do: code

  defp generate_message_id do
    Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end

  defp now_iso do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp format_device_name(device_name, ip_str) do
    suffix = ip_str |> String.split(".") |> List.last()
    "#{device_name} · #{suffix}"
  end

  defp extract_room_and_mode(req) do
    qs = :cowboy_req.parse_qs(req)

    room_code =
      Enum.find_value(qs, fn
        {"room", value} -> LanShare.Room.normalize(value)
        _ -> nil
      end)

    mode =
      Enum.find_value(qs, fn
        {"mode", value} -> LanShare.Room.normalize_mode(value)
        _ -> nil
      end) || LanShare.Room.default_mode()

    {room_code, mode}
  end

  defp valid_inline_image?("data:image/" <> _rest = data) do
    byte_size(data) <= @max_inline_image_size * 2
  end

  defp valid_inline_image?(_), do: false

  defp sanitize_filename(filename) when is_binary(filename) and filename != "" do
    Path.basename(filename)
  end

  defp sanitize_filename(_), do: "image"

  defp build_file_message(file_id, %{room_code: nil} = state) do
    case LanShare.FileStore.lookup(file_id) do
      {:ok, metadata} when metadata.room_code == "_LOBBY" ->
        {:ok,
         %{
           id: metadata.id,
           type: "file",
           filename: metadata.filename,
           size: metadata.size,
           content_type: metadata.content_type,
           download_url: LanShare.FileStore.download_url(metadata.id, "_LOBBY"),
           sender: state.device_name,
           timestamp: now_iso(),
           room_code: nil
         }}

      _ ->
        :error
    end
  end

  defp build_file_message(file_id, state) do
    case LanShare.FileStore.lookup(file_id) do
      {:ok, metadata} when metadata.room_code == state.room_code ->
        {:ok,
         %{
           id: metadata.id,
           type: "file",
           filename: metadata.filename,
           size: metadata.size,
           content_type: metadata.content_type,
           download_url: LanShare.FileStore.download_url(metadata.id, metadata.room_code),
           sender: state.device_name,
           timestamp: now_iso(),
           room_code: metadata.room_code
         }}

      _ ->
        :error
    end
  end
end
