# LanShare

轻量级局域网共享工具。一台设备启动服务后，局域网内其他设备直接通过浏览器访问即可互发文字和图片。

## 功能

- WebSocket 实时聊天
- 图片 Data URI 直传与预览
- 在线设备列表
- 最近 100 条消息历史
- 自动重连与 30 秒心跳保活

## 启动

```bash
mix deps.get
mix run --no-halt
```

默认监听端口是 `10086`。

启动后终端会输出类似地址：

```text
LanShare 启动于 http://0.0.0.0:10086
局域网内其他设备请访问 http://192.168.x.x:10086
```

## HTTP 接口

- `GET /`：单页应用
- `GET /api/devices`：返回当前在线设备列表
- `POST /upload`：图片上传备用通道

## 测试

```bash
mix test
```

