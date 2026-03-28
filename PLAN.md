# LanShare - 局域网共享程序 计划书

## 项目概述

轻量级局域网内文字/图片共享工具。一台设备运行服务端，同一局域网内其他设备通过浏览器访问即可互相通信。**无需配对，无需安装客户端**。

## 技术选型

| 组件 | 选择 | 理由 |
|------|------|------|
| HTTP 服务器 | `plug_cowboy` | 轻量，Cowboy 原生支持 WebSocket |
| 路由 | `plug` | 简洁够用，不需要 Phoenix 的复杂度 |
| JSON | `jason` | Elixir 社区标准 JSON 库 |
| 设备识别 | 自写 UA 解析 | 避免外部依赖，正则匹配足够 |
| 前端 | 内嵌单页 HTML | 零部署成本，一个 `mix run --no-halt` 启动一切 |
| 实时通信 | Cowboy WebSocket | 原生支持，无需额外框架 |

## 架构设计

```
浏览器 A ──┐
浏览器 B ──┤── WebSocket ──→ Cowboy ──→ WebSocket Handler
浏览器 C ──┘                   │
                               ├── DeviceRegistry (GenServer) ─ 设备管理
                               ├── MessageStore (GenServer) ─── 消息历史
                               └── Router (Plug) ────────────── HTTP 路由
```

## 文件结构

```
lan_share/
├── mix.exs                          # 依赖声明
├── config/config.exs                # 端口等配置
├── PLAN.md                          # 本文件
├── lib/
│   ├── lan_share.ex                 # 主模块，工具函数
│   └── lan_share/
│       ├── application.ex           # OTP Application，启动监督树
│       ├── router.ex                # Plug 路由 (HTTP)
│       ├── websocket.ex             # Cowboy WebSocket Handler
│       ├── device_registry.ex       # GenServer - 在线设备管理
│       ├── message_store.ex         # GenServer - 消息历史缓存
│       ├── ua_parser.ex             # User-Agent 解析 → 设备名称
│       └── page.ex                  # 内嵌 HTML 单页应用
└── test/
```

## 核心模块说明

### 1. DeviceRegistry (GenServer)
- 维护 `%{pid => device_name}` 映射
- WebSocket 连接时注册，断开时通过 `Process.monitor` 自动清理
- 提供 `broadcast/1` 向所有在线设备推送消息
- 设备上下线时广播系统通知 + 最新设备列表

### 2. MessageStore (GenServer)
- 环形缓冲区，保留最近 100 条消息
- 新设备加入时推送历史消息，保证不错过之前的内容

### 3. WebSocket Handler
- 处理消息类型: `text`(文字)、`image`(图片)、`ping`(心跳)
- 图片以 Base64 Data URI 传输，前端直接渲染
- 连接建立时从 HTTP 请求头提取 User-Agent

### 4. UAParser
- 从 User-Agent 提取设备类型 + 浏览器信息
- 支持: iPhone/iPad/Android设备/Mac/Windows/Linux/Chromebook
- 输出格式: `"iPhone (Safari)"`, `"Windows PC (Chrome)"` 等

### 5. Router (Plug)
- `GET /` → 单页 HTML 应用
- `POST /upload` → HTTP 图片上传 (大文件备用通道)
- `GET /api/devices` → 在线设备列表 JSON

### 6. Page (内嵌前端)
- 类似即时通讯的聊天 UI
- 功能: 文字发送、图片选择发送、在线设备列表侧边栏、图片点击放大
- 自动重连机制、30 秒心跳保活
- 完全响应式，适配手机和桌面

## 使用方式

```bash
# 安装依赖
cd lan_share && mix deps.get

# 启动服务
mix run --no-halt

# 或在 iex 中启动
iex -S mix
```

启动后终端会显示:
```
LanShare 启动于 http://0.0.0.0:10086（请修改端口为10086）
局域网内其他设备请访问 http://<本机IP>:端口
```

同一局域网内的设备用浏览器打开地址即可使用。

## 后续可扩展功能

- [ ] 文件传输 (非图片文件)
- [ ] 设备自定义昵称 (覆盖 UA 解析结果)
- [ ] mDNS 自动发现 (让设备无需手动输入 IP)
- [ ] 消息加密
- [ ] 剪贴板同步
- [ ] 拖拽上传
