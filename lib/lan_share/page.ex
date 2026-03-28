defmodule LanShare.Page do
  @moduledoc """
  内嵌的单页 HTML 应用。
  包含聊天界面、图片发送、在线设备列表。
  """

  def render do
    ~S"""
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>LanShare - 局域网共享</title>
      <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%23075e54'/%3E%3Ccircle cx='22' cy='22' r='8' fill='white'/%3E%3Ccircle cx='42' cy='22' r='8' fill='white' fill-opacity='.82'/%3E%3Ccircle cx='32' cy='42' r='8' fill='white' fill-opacity='.92'/%3E%3C/svg%3E">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          background: #f0f2f5;
          height: 100vh;
          display: flex;
          flex-direction: column;
        }

        /* 顶部栏 */
        .header {
          background: #075e54;
          color: white;
          padding: 12px 16px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          box-shadow: 0 2px 4px rgba(0,0,0,0.15);
        }
        .header h1 { font-size: 18px; font-weight: 600; }
        .device-count {
          background: rgba(255,255,255,0.2);
          padding: 4px 10px;
          border-radius: 12px;
          font-size: 13px;
          cursor: pointer;
        }

        /* 设备侧边栏 */
        .sidebar {
          display: none;
          position: fixed;
          top: 0; right: 0; bottom: 0;
          width: 260px;
          background: white;
          box-shadow: -2px 0 8px rgba(0,0,0,0.15);
          z-index: 100;
          flex-direction: column;
        }
        .sidebar.open { display: flex; }
        .sidebar-header {
          background: #075e54;
          color: white;
          padding: 14px 16px;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .sidebar-header h2 { font-size: 16px; }
        .sidebar-close { background: none; border: none; color: white; font-size: 22px; cursor: pointer; }
        .device-list { flex: 1; overflow-y: auto; padding: 8px; }
        .device-item {
          padding: 10px 12px;
          border-bottom: 1px solid #eee;
          font-size: 14px;
          display: flex;
          align-items: center;
          gap: 8px;
        }
        .device-dot {
          width: 8px; height: 8px;
          background: #25d366;
          border-radius: 50%;
          flex-shrink: 0;
        }

        /* 消息区域 */
        .messages {
          flex: 1;
          overflow-y: auto;
          padding: 16px;
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .msg {
          max-width: 75%;
          padding: 8px 12px;
          border-radius: 8px;
          font-size: 14px;
          line-height: 1.4;
          word-wrap: break-word;
        }
        .msg.text-msg { background: white; align-self: flex-start; }
        .msg.text-msg.mine { background: #dcf8c6; align-self: flex-end; }
        .msg .sender {
          font-size: 12px;
          font-weight: 600;
          color: #075e54;
          margin-bottom: 2px;
        }
        .msg .time {
          font-size: 11px;
          color: #999;
          text-align: right;
          margin-top: 4px;
        }
        .msg.system-msg {
          align-self: center;
          background: rgba(0,0,0,0.06);
          color: #666;
          font-size: 12px;
          padding: 4px 12px;
          border-radius: 16px;
        }
        .msg img {
          max-width: 100%;
          max-height: 300px;
          border-radius: 6px;
          cursor: pointer;
        }

        /* 输入区域 */
        .input-area {
          background: white;
          padding: 10px 16px;
          display: flex;
          gap: 8px;
          align-items: flex-end;
          border-top: 1px solid #e0e0e0;
        }
        .input-area textarea {
          flex: 1;
          border: 1px solid #ddd;
          border-radius: 20px;
          padding: 8px 14px;
          font-size: 14px;
          resize: none;
          max-height: 100px;
          outline: none;
          font-family: inherit;
        }
        .input-area textarea:focus { border-color: #075e54; }
        .btn {
          width: 40px; height: 40px;
          border-radius: 50%;
          border: none;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
        }
        .btn-send { background: #075e54; color: white; font-size: 18px; }
        .btn-image { background: #e0e0e0; color: #555; font-size: 20px; }
        .btn:active { opacity: 0.7; }

        input[type="file"] { display: none; }

        /* 图片预览遮罩 */
        .overlay {
          display: none;
          position: fixed;
          top: 0; left: 0; right: 0; bottom: 0;
          background: rgba(0,0,0,0.85);
          z-index: 200;
          align-items: center;
          justify-content: center;
          cursor: pointer;
        }
        .overlay.open { display: flex; }
        .overlay img {
          max-width: 95%;
          max-height: 95%;
          object-fit: contain;
        }

        /* 连接状态 */
        .status-bar {
          text-align: center;
          padding: 4px;
          font-size: 12px;
          color: white;
        }
        .status-bar.connected { background: #25d366; }
        .status-bar.disconnected { background: #e74c3c; }
        .status-bar.connecting { background: #f39c12; }
      </style>
    </head>
    <body>
      <div class="status-bar connecting" id="statusBar">连接中...</div>

      <div class="header">
        <h1>LanShare</h1>
        <div class="device-count" id="deviceCount" onclick="toggleSidebar()">
          0 在线
        </div>
      </div>

      <div class="sidebar" id="sidebar">
        <div class="sidebar-header">
          <h2>在线设备</h2>
          <button class="sidebar-close" onclick="toggleSidebar()">&times;</button>
        </div>
        <div class="device-list" id="deviceList"></div>
      </div>

      <div class="messages" id="messages"></div>

      <div class="input-area">
        <button class="btn btn-image" onclick="document.getElementById('fileInput').click()">
          &#128247;
        </button>
        <input type="file" id="fileInput" accept="image/*" onchange="handleImageSelect(event)">
        <textarea id="textInput" rows="1" placeholder="输入消息..."
          onkeydown="handleKeyDown(event)"
          oninput="autoResize(this)"></textarea>
        <button class="btn btn-send" onclick="sendText()">&#9654;</button>
      </div>

      <div class="overlay" id="overlay" onclick="closeOverlay()">
        <img id="overlayImg" src="">
      </div>

      <script>
        let ws;
        let myName = '';
        let reconnectTimer;
        let shouldStickToBottom = true;

        const messagesEl = document.getElementById('messages');

        messagesEl.addEventListener('scroll', () => {
          const threshold = 32;
          shouldStickToBottom = messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight < threshold;
        });

        function connect() {
          const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
          ws = new WebSocket(`${protocol}//${location.host}/ws`);

          ws.onopen = () => {
            document.getElementById('statusBar').className = 'status-bar connected';
            document.getElementById('statusBar').textContent = '已连接';
            clearTimeout(reconnectTimer);
          };

          ws.onclose = () => {
            document.getElementById('statusBar').className = 'status-bar disconnected';
            document.getElementById('statusBar').textContent = '连接断开，正在重连...';
            reconnectTimer = setTimeout(connect, 2000);
          };

          ws.onerror = () => {
            ws.close();
          };

          ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            handleMessage(msg);
          };
        }

        function handleMessage(msg) {
          switch (msg.type) {
            case 'welcome':
              myName = msg.device_name || '';
              if (msg.devices) updateDeviceList(msg.devices);
              break;
            case 'history':
              msg.messages.forEach(m => renderMessage(m));
              scrollToBottom();
              break;
            case 'text':
              renderMessage(msg);
              scrollToBottom();
              break;
            case 'image':
              renderMessage(msg);
              scrollToBottom();
              break;
            case 'system':
              renderSystem(msg.content);
              if (msg.devices) updateDeviceList(msg.devices);
              scrollToBottom();
              break;
            case 'pong':
              break;
          }
        }

        function renderMessage(msg) {
          const container = document.getElementById('messages');
          const div = document.createElement('div');
          const isMine = msg.sender === myName;

          if (msg.type === 'text') {
            div.className = `msg text-msg${isMine ? ' mine' : ''}`;
            div.innerHTML = `
              ${!isMine ? `<div class="sender">${escapeHtml(msg.sender)}</div>` : ''}
              <div>${escapeHtml(msg.content)}</div>
              <div class="time">${formatTime(msg.timestamp)}</div>
            `;
          } else if (msg.type === 'image') {
            div.className = `msg text-msg${isMine ? ' mine' : ''}`;
            div.innerHTML = `
              ${!isMine ? `<div class="sender">${escapeHtml(msg.sender)}</div>` : ''}
              <img src="${msg.data}" alt="${escapeHtml(msg.filename)}" onclick="openOverlay(this.src)">
              <div class="time">${formatTime(msg.timestamp)}</div>
            `;
          }

          container.appendChild(div);
        }

        function renderSystem(text) {
          const container = document.getElementById('messages');
          const div = document.createElement('div');
          div.className = 'msg system-msg';
          div.textContent = text;
          container.appendChild(div);
        }

        function updateDeviceList(devices) {
          const countEl = document.getElementById('deviceCount');
          countEl.textContent = `${devices.length} 在线`;

          const listEl = document.getElementById('deviceList');
          listEl.innerHTML = devices.map(d =>
            `<div class="device-item">
              <span class="device-dot"></span>
              <span>${escapeHtml(d)}${d === myName ? ' (我)' : ''}</span>
            </div>`
          ).join('');
        }

        function sendText() {
          const input = document.getElementById('textInput');
          const text = input.value.trim();
          if (!text || !ws || ws.readyState !== WebSocket.OPEN) return;

          ws.send(JSON.stringify({ type: 'text', content: text }));
          input.value = '';
          input.style.height = 'auto';
        }

        function handleImageSelect(event) {
          const file = event.target.files[0];
          if (!file) return;

          // 限制 5MB
          if (file.size > 5 * 1024 * 1024) {
            alert('图片大小不能超过 5MB');
            event.target.value = '';
            return;
          }

          const reader = new FileReader();
          reader.onload = (e) => {
            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({
                type: 'image',
                data: e.target.result,
                filename: file.name
              }));
            }
          };
          reader.readAsDataURL(file);
          event.target.value = '';
        }

        function handleKeyDown(event) {
          if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            sendText();
          }
        }

        function autoResize(el) {
          el.style.height = 'auto';
          el.style.height = Math.min(el.scrollHeight, 100) + 'px';
        }

        function toggleSidebar() {
          document.getElementById('sidebar').classList.toggle('open');
        }

        function openOverlay(src) {
          document.getElementById('overlayImg').src = src;
          document.getElementById('overlay').classList.add('open');
        }

        function closeOverlay() {
          document.getElementById('overlay').classList.remove('open');
        }

        function scrollToBottom() {
          if (!shouldStickToBottom) return;
          const el = document.getElementById('messages');
          el.scrollTop = el.scrollHeight;
        }

        function escapeHtml(text) {
          const div = document.createElement('div');
          div.textContent = text;
          return div.innerHTML;
        }

        function formatTime(iso) {
          if (!iso) return '';
          const d = new Date(iso);
          return d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
        }

        // 心跳保活
        setInterval(() => {
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'ping' }));
          }
        }, 30000);

        // 启动连接
        connect();
      </script>
    </body>
    </html>
    """
  end
end
