# LanShare

轻量级局域网 / VPS 中转共享工具。一台设备启动服务后,同 LAN 设备直接通过浏览器互发文字、图片和文件;部署到 VPS 后还能给异地设备做信令转发,但同 LAN 仍然走 P2P 直连。

## 功能

- **双模式房间** —— `lan`(WebRTC P2P,服务器零信任)/ `relay`(经服务器中转 + 持久化历史)
- WebSocket 实时聊天 + 信令通道
- 图片 Data URI 直传与预览
- 房间内 1GB 文件上传与下载(relay 模式)/ 64KB 分片 DataChannel 直传(lan 模式)
- 在线设备列表 + 稳定 peer_id
- 最近 100 条消息历史(relay 模式)
- SQLite 持久化消息历史
- 4 位房间码私密房间
- 房间二维码分享
- Markdown 消息渲染与源码复制
- 长文本会自动转成 Markdown 或 HTML 文件发送,避免大段内容被截断(relay 模式)
- `.md` / `.html` 等文本文件消息支持在聊天气泡内直接预览源码
- 可预览文本文件会保留"复制源码"快捷按钮,HTML 额外支持 sandbox 安全预览
- 自动重连与 30 秒心跳保活
- 页面样式为内联本地 CSS,不依赖 Tailwind CDN

## 房间模式

| 模式 | URL | 数据通道 | 服务器角色 | 安全模型 | 适用 |
|---|---|---|---|---|---|
| **`lan`(默认)** | `/r/AB12?mode=lan` | WebRTC `RTCDataChannel`,只采集 host ICE 候选(192.168/10/172.16/`fe80:`/`.local`) | 仅信令 + 在线设备列表,**不存不转**消息和文件 | 跨网设备 ICE 必然失败 → 拿到房间码也连不上 → 物理隔离 | 家庭/办公室同一 LAN,异地通过 Tailscale/WireGuard 拉到同一虚拟 LAN |
| **`relay`** | `/r/AB12?mode=relay` | WebSocket(走服务器) | 转发 + 持久化历史(SQLite)+ 文件存储(`var/uploads/`)| 房间码即权限,适合可信小群 | 公网部署给异地协作,VPS 中转 |

房间的模式由**第一位进入该房间的设备**决定,后续设备自动继承,模式记录在 [DeviceRegistry](lib/lan_share/device_registry.ex) 内存中(服务重启会重置)。顶部栏的「局域网 / 中继」徽章实时显示当前模式。

`lan` 模式下:
- 文本/图片/文件全部走 `RTCDataChannel`,服务器看不到内容
- 文件用 64KB 二进制分片 + `LSC0` magic header + transferId + seq + payload,接收端按序拼成 Blob
- 服务器只转发 SDP / ICE 信令(`{type:"signal", to: peer_id, payload}`)
- 删除是本地操作 + DataChannel 广播,不持久化

## 启动

### 本机/局域网

```bash
mix deps.get
mix run --no-halt
```

默认监听端口是 `10086`。消息历史默认落盘到 `var/lan_share.sqlite3`。

启动后终端会输出类似地址:

```text
LanShare 启动于 http://0.0.0.0:10086
局域网内其他设备请访问 http://192.168.x.x:10086
```

### 部署到 VPS(信令 + 中继)

详见 [scripts/deploy.toml](scripts/deploy.toml) 和 [scripts/deploy.exs](scripts/deploy.exs):

```bash
# 1. 改 scripts/deploy.toml,填 host / domain / 端口
# 2. (可选)cp .env.prod.example .env.prod 并填入 PORT 等
elixir scripts/deploy.exs                       # 完整部署
elixir scripts/deploy.exs --rollback            # 回滚到上一版本
```

开启 `[caddy]` 段会**用原生 apt 装 Caddy + 自动签发 Let's Encrypt 证书**,前端 `wss://` / WebRTC secure context 一步到位。仅支持 Debian/Ubuntu。

构建机与目标 VPS 必须 OS+架构一致(`exqlite` 是 NIF)。如果本地是 Windows/macOS,见 [scripts/BUILDER_PLAN.md](scripts/BUILDER_PLAN.md) 的"专用构建机"方案。

## HTTP 接口

- `GET /` / `GET /?mode=lan|relay`:单页应用,大厅模式
- `GET /r/:code` / `GET /r/:code?mode=lan|relay`:进入指定房间(mode 参数仅在房间未被首位设备锁定时生效)
- `GET /r/:code/qrcode.svg`:返回房间分享二维码 SVG
- `GET /room/new?mode=lan|relay`:创建随机房间并跳转(默认 `mode=lan`)
- `POST /join`:提交 4 位房间码 + 可选 `mode` 并跳转
- `GET /api/devices?room=AB12`:返回当前房间在线设备列表
- `POST /upload`:图片上传备用通道(relay 模式专用)
- `POST /upload/file`:房间文件上传,返回文件元数据(relay 模式专用)
- `GET /files/:id?room=AB12`:按房间校验后下载文件(relay 模式专用)
- `WebSocket /ws?room=AB12&mode=lan|relay`:消息 + 信令通道,支持以下消息类型:
  - 客户端 → 服务端:`text` / `image` / `file` / `delete` / `ping`(仅 relay)、`signal`(双模式都支持)
  - 服务端 → 客户端:`welcome`(含 `peer_id`、`mode`、`peers`)、`history`、`text` / `image` / `file`、`signal`、`system`(含 `peer_id` + `event: "join"|"leave"`)、`deleted`、`pong`

## 房间功能

- 房间码固定为 4 位字母或数字,大小写不敏感,界面统一显示为大写
- 顶部"新建·LAN" / "新建·中继"按钮分别创建对应模式的随机房间
- 房间页面的二维码由服务端生成 SVG,其他设备扫码即可加入(分享链接保留 `?mode=...`)
- 房间内的消息历史、在线设备和上下线通知彼此隔离
- **lan 模式**:文件不经过服务器,各端浏览器内 Blob;关闭页面或离开房间后文件副本随 blob URL 一起释放
- **relay 模式**:文件实体默认保存在 `var/uploads/`,服务重启后旧文件消息仍会显示,但重启前上传的文件不会重新建立下载索引
- 服务重启后最近 100 条房间消息会从 SQLite 恢复(仅 relay 模式)

## 消息删除

- 每条消息(文本 / 图片 / 文件)右下角都有「删除」按钮,仅在你有权限时显示
- **relay 模式**:仅 **消息发送者本人** 或 **房间创建者**(即第一位进入该房间的设备)可以删除消息;删除会级联清理 SQLite 历史记录 + 上传文件磁盘实体 + FileStore 内存索引,同房间所有客户端实时移除该气泡
- **lan 模式**:删除是本地操作 + DataChannel 广播给所有 peer,客户端直接移除气泡;服务器无消息可删

### 已知身份限制(主要影响 relay 模式)

- 设备身份目前由「User-Agent 推断的设备名 + 局域网 IP 末段」组成,不是持久 ID
- relay 模式公网部署时,IP 末段可能撞车 / 跨网漂移,删除/创建者权限不可靠
- 因此换设备、换网络、IP 末段冲突或重启服务等情况都会改变身份:
  - 换设备 / 换浏览器 / 换网络后,原创建者将无法再删除自己之前发的消息
  - 房间创建者身份记录在内存中,**服务重启后会重新由首位重连的设备接管**
- lan 模式不依赖身份做权限校验,影响只是"重连后无法再删除自己之前的旧气泡"
- 如果希望在 LAN 工具范围之外做更严肃的身份控制,需要后续接入 Cookie/Token 持久化身份(暂未实现)
vps
## Markdown 消息

- 文本消息由服务端使用纯 Elixir Markdown 库渲染为 HTML(仅 relay 模式)
- lan 模式下文本走 DataChannel,不经服务端,因此不做服务端 Markdown 渲染;前端用后备渲染显示原文 + 换行
- 前端展示渲染结果,支持列表、引用、代码块、行内代码等常见 Markdown 语法
- 每条文本消息都提供"复制源码"按钮,复制的是原始 Markdown 文本,不是渲染后的 HTML
- 当输入内容超过阈值时,前端会自动改走文件上传:检测到完整 HTML 结构时保存为 `.html`,其他长文本默认保存为 `.md`(仅 relay 模式;lan 模式直接通过 DataChannel 发送原文)
- `.md`、`.html`、`.txt`、`.json`、`.xml` 等文本文件会显示"预览源码"按钮,预览通过下载接口读取原始文本,不在页面内直接执行 HTML
- 文件预览弹层支持 Esc、遮罩点击、底部关闭按钮;HTML 文件可在源码和 sandbox iframe 安全预览之间切换

## 测试

```bash
mix test
```

## 构建发布包(Release)

> 想一键部署到 VPS 见 [scripts/deploy.exs](scripts/deploy.exs);本节是手动构建说明。

项目使用 Elixir 内置的 `mix release` 打包,对方机器无需安装 Elixir/Erlang 即可运行,但 release **必须在与目标机器相同的操作系统、相同 CPU 架构** 下构建(`exqlite` 是 NIF)。

发布包默认把数据写到 release 解压目录的 `var/` 下(和 `bin/` 同级),无需额外配置。也可通过环境变量覆盖:

- `PORT`:监听端口,默认 `10086`
- `LAN_SHARE_DB`:SQLite 文件绝对路径
- `LAN_SHARE_UPLOAD_ROOT`:上传文件目录绝对路径

### Linux / macOS 上构建

```bash
mix deps.get --only prod
MIX_ENV=prod mix release
```

产物：

- 目录：`_build/prod/rel/lan_share/`
- 压缩包：`_build/prod/lan_share-0.1.0.tar.gz`

对方解压后运行：

```bash
tar -xzf lan_share-0.1.0.tar.gz -C lan_share
cd lan_share
./bin/lan_share start          # 前台运行
./bin/lan_share daemon         # 后台运行
./bin/lan_share stop           # 停止
PORT=8080 ./bin/lan_share start  # 自定义端口
```

### Windows 上构建（PowerShell）

PowerShell 不支持 `MIX_ENV=prod mix release` 这种内联写法，需要先设置环境变量再执行：

```powershell
mix deps.get --only prod
$env:MIX_ENV = "prod"
mix release
```

如果用 CMD：

```bat
set MIX_ENV=prod
mix deps.get --only prod
mix release
```

产物：

- 目录：`_build\prod\rel\lan_share\`
- 压缩包：`_build\prod\lan_share-0.1.0.tar.gz`

对方解压后用 PowerShell 或 CMD 运行：

```powershell
.\bin\lan_share.bat start          # 前台运行
.\bin\lan_share.bat install        # 安装为 Windows 服务（可选）
.\bin\lan_share.bat stop           # 停止
$env:PORT = "8080"; .\bin\lan_share.bat start
```

> 注意：如果你看到日志里写的是 `MIX_ENV=dev`，说明环境变量没生效，请先确认 `$env:MIX_ENV` / `echo %MIX_ENV%` 输出确实是 `prod` 再执行 `mix release`。

### 跨平台说明

`include_executables_for: [:unix, :windows]` 已经让 release 同时生成 `bin/lan_share` 和 `bin\lan_share.bat`，但 BEAM 运行时和 NIF（`exqlite`）会绑定当前编译机：

- 在 Windows 上构建的 release 只能给 Windows 用户使用
- 在 Linux 上构建的 release 只能给同架构的 Linux 用户使用
- 给 macOS 用户请在 macOS 上构建
