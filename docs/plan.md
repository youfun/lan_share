# 子房间（Room）功能实施计划

目的：为现有局域网聊天增加轻量房间机制，使设备可通过短链接、短码输入或扫码进入同一私密房间，并确保消息历史与在线设备列表按房间隔离。

## 已定方案

- 1A：房间码默认由服务器生成随机 4 字符，前端仍支持手动输入已有房间码加入
- 2A：房间状态仅保存在内存，服务重启后房间与历史消息清空
- 3A：二维码改为后端生成 SVG，由房间页面直接加载本地路由

选择理由：

- 局域网环境不应依赖外部 CDN，因此二维码改为本地后端生成更可靠
- 房间如果不做真实数据隔离，功能会失真，因此核心工作放在 WebSocket 和状态分房间
- 4 字符房间码足够轻量，适合局域网临时分享场景

## 功能范围

- 支持通过 URL 进入房间，例如 `http://HOST:10086/r/AB12`
- 支持首页输入 4 字符房间码并跳转加入
- 支持一键创建随机房间并生成可分享二维码
- 房间码仅允许字母和数字，长度固定为 4，服务端统一规范化为大写显示、校验时大小写不敏感
- 消息历史、设备列表、上下线通知都按房间隔离
- 根路径 `/` 仍可作为公共大厅使用

## 实现设计

### 1. 路由层

- 更新 [lib/lan_share/router.ex](lib/lan_share/router.ex)
- 新增路由：
  - `GET /`：渲染大厅页面
  - `GET /r/:code`：校验房间码后渲染带初始房间信息的页面
  - `GET /r/:code/qrcode.svg`：返回房间分享二维码 SVG
  - `POST /join`：接收房间码并重定向到 `/r/:code`
  - `GET /room/new`：生成随机房间码并重定向到 `/r/:code`
- 非法房间码返回 `400`

### 2. 房间模型

- 新增 [lib/lan_share/room.ex](lib/lan_share/room.ex)
- 提供：
  - 房间码校验
  - 规范化函数
  - 随机码生成函数
  - 路径构建辅助函数

### 3. 二维码输出

- 新增 [lib/lan_share/room_qr_code.ex](lib/lan_share/room_qr_code.ex)
- 使用纯 Elixir `qr_code` 库输出 SVG
- 前端二维码弹窗仅负责展示 `/r/:code/qrcode.svg`，不再依赖外部 JS CDN

### 4. 状态隔离

- 更新 [lib/lan_share/device_registry.ex](lib/lan_share/device_registry.ex)
  - 设备注册增加 `room_code`
  - 设备列表按房间返回
  - 广播按房间投递
  - 上下线系统消息仅广播给同房间成员
- 更新 [lib/lan_share/message_store.ex](lib/lan_share/message_store.ex)
  - 消息历史改为按房间存储
  - 每个房间独立保留最近 100 条消息
- 更新 [lib/lan_share/websocket.ex](lib/lan_share/websocket.ex)
  - 从 WebSocket URL query 中读取房间码
  - 欢迎消息、历史消息、文本/图片广播都带房间上下文

### 5. 前端页面

- 更新 [lib/lan_share/page.ex](lib/lan_share/page.ex)
- 新增房间条：
  - 当前房间显示
  - 4 字符房间码输入与加入按钮
  - 创建随机房间按钮
  - 显示二维码按钮
  - 返回大厅按钮
- WebSocket 连接时自动带上房间参数
- 页面样式内联，不依赖 Tailwind CDN
- 二维码图片直接加载本地 SVG 路由

### 6. 文档与测试

- 更新 [README.md](README.md)
- 新增测试覆盖：
  - 房间码校验与规范化
  - 随机房间码格式
  - `/r/:code` 页面注入房间信息
  - `/r/:code/qrcode.svg` 返回有效 SVG
  - `/join` 跳转行为
  - 非法房间码返回 `400`

## 风险与约束

- 4 位字母数字共有 $36^4 = 1,679,616$ 种组合，局域网临时使用足够，但不是安全边界
- 当前房间是“软创建”，即访问即存在，不做单独的房间生命周期管理
- 内存态实现不会跨重启保留数据，也不适合多节点部署

## 实施步骤

1. 补全房间模型与路由
2. 改造设备注册表与消息历史为按房间隔离
3. 接入后端 SVG 二维码输出
4. 改造 WebSocket 连接与广播逻辑
5. 更新单页 UI 与二维码分享
6. 增加测试并同步 README
