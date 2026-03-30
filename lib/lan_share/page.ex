defmodule LanShare.Page do
  @moduledoc """
  内嵌的单页 HTML 应用。
  包含聊天界面、房间切换、图片发送、在线设备列表。
  """

  def render(room_code \\ nil) do
    assigns = %{
      room_code: room_code,
      room_label: LanShare.Room.label(room_code)
    }

    """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>LanShare - 局域网共享</title>
      <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%23075e54'/%3E%3Ccircle cx='22' cy='22' r='8' fill='white'/%3E%3Ccircle cx='42' cy='22' r='8' fill='white' fill-opacity='.82'/%3E%3Ccircle cx='32' cy='42' r='8' fill='white' fill-opacity='.92'/%3E%3C/svg%3E">
      <style>
        :root {
          --brand: #075e54;
          --brand-light: #128c7e;
          --bubble-mine: #dcf8c6;
          --bg-app: #f3f4f6;
          --text-strong: #1f2937;
          --text-muted: #6b7280;
          --border-soft: #d1d5db;
          --border-faint: #e5e7eb;
          --overlay-soft: rgba(0, 0, 0, 0.3);
          --overlay-medium: rgba(0, 0, 0, 0.5);
          --overlay-strong: rgba(0, 0, 0, 0.85);
          --success: #22c55e;
          --danger: #ef4444;
          --warning: #eab308;
        }

        * { box-sizing: border-box; }

        html, body {
          margin: 0;
          height: 100%;
        }

        body {
          background: var(--bg-app);
          color: var(--text-strong);
          display: flex;
          flex-direction: column;
          font-family: "Segoe UI", "PingFang SC", "Noto Sans SC", sans-serif;
          overflow: hidden;
        }

        button, input, textarea {
          font: inherit;
        }

        a {
          color: inherit;
          text-decoration: none;
        }

        .hidden { display: none !important; }
        .flex { display: flex; }
        .block { display: block; }
        .flex-col { flex-direction: column; }
        .flex-1 { flex: 1 1 auto; }
        .flex-shrink-0 { flex-shrink: 0; }
        .flex-wrap { flex-wrap: wrap; }
        .items-center { align-items: center; }
        .items-start { align-items: flex-start; }
        .items-end { align-items: flex-end; }
        .justify-between { justify-content: space-between; }
        .justify-center { justify-content: center; }
        .justify-end { justify-content: flex-end; }
        .justify-start { justify-content: flex-start; }
        .self-center { align-self: center; }
        .gap-2 { gap: 0.5rem; }
        .gap-3 { gap: 0.75rem; }
        .min-h-0 { min-height: 0; }
        .min-h-64 { min-height: 16rem; }
        .h-screen { height: 100vh; }
        .h-10 { height: 2.5rem; }
        .h-2 { height: 0.5rem; }
        .h-64 { height: 16rem; }
        .w-10 { width: 2.5rem; }
        .w-2 { width: 0.5rem; }
        .w-64 { width: 16rem; }
        .w-full { width: 100%; }
        .max-w-full { max-width: 100%; }
        .max-w-sm { max-width: 24rem; }
        .max-h-28 { max-height: 7rem; }
        .overflow-hidden { overflow: hidden; }
        .overflow-y-auto { overflow-y: auto; }
        .resize-none { resize: none; }
        .cursor-pointer { cursor: pointer; }
        .rounded-full { border-radius: 999px; }
        .rounded-lg { border-radius: 0.75rem; }
        .rounded-xl { border-radius: 1rem; }
        .rounded-2xl { border-radius: 1.25rem; }
        .rounded-3xl { border-radius: 1.5rem; }
        .border { border: 1px solid var(--border-soft); }
        .border-t { border-top: 1px solid var(--border-faint); }
        .border-b { border-bottom: 1px solid var(--border-faint); }
        .border-gray-200 { border-color: var(--border-faint); }
        .border-gray-300 { border-color: var(--border-soft); }
        .border-brand { border-color: var(--brand); }
        .bg-white { background: #fff; }
        .bg-gray-50 { background: #f9fafb; }
        .bg-gray-100 { background: var(--bg-app); }
        .bg-gray-900 { background: #111827; }
        .bg-black { background: #000; }
        .bg-brand { background: var(--brand); }
        .bg-brand-light { background: var(--brand-light); }
        .bg-green-500 { background: var(--success); }
        .bg-red-500 { background: var(--danger); }
        .bg-yellow-500 { background: var(--warning); }
        .bg-green-400 { background: #4ade80; }
        .text-white { color: #fff; }
        .text-brand { color: var(--brand); }
        .text-gray-400 { color: #9ca3af; }
        .text-gray-500 { color: var(--text-muted); }
        .text-gray-600 { color: #4b5563; }
        .text-gray-700 { color: #374151; }
        .text-gray-800 { color: var(--text-strong); }
        .text-gray-900 { color: #111827; }
        .text-center { text-align: center; }
        .text-right { text-align: right; }
        .text-xs { font-size: 0.75rem; }
        .text-sm { font-size: 0.875rem; }
        .text-base { font-size: 1rem; }
        .text-lg { font-size: 1.125rem; }
        .text-xl { font-size: 1.25rem; }
        .text-2xl { font-size: 1.5rem; }
        .font-medium { font-weight: 500; }
        .font-semibold { font-weight: 600; }
        .uppercase { text-transform: uppercase; }
        .leading-none { line-height: 1; }
        .leading-relaxed { line-height: 1.65; }
        .outline-none { outline: none; }
        .break-words { overflow-wrap: anywhere; }
        .truncate {
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
        .object-contain { object-fit: contain; }
        .shadow-sm { box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08); }
        .shadow-md { box-shadow: 0 14px 28px rgba(15, 23, 42, 0.12); }
        .shadow-2xl { box-shadow: 0 28px 64px rgba(15, 23, 42, 0.22); }
        .transition-colors { transition: background-color 0.18s ease, border-color 0.18s ease, color 0.18s ease; }
        .transition-opacity { transition: opacity 0.18s ease; }
        .duration-300 { transition-duration: 0.3s; }
        .fixed { position: fixed; }
        .top-0 { top: 0; }
        .right-0 { right: 0; }
        .bottom-0 { bottom: 0; }
        .inset-0 { inset: 0; }
        .z-40 { z-index: 40; }
        .z-50 { z-index: 50; }
        .font-sans { font-family: inherit; }
        .divide-y > * + * { border-top: 1px solid #f3f4f6; }

        [class~="max-w-[95vw]"] { max-width: 95vw; }
        [class~="max-h-[95vh]"] { max-height: 95vh; }
        [class~="max-w-[75%]"] { max-width: 75%; }
        [class~="max-h-72"] { max-height: 18rem; }
        [class~="bg-[#dcf8c6]"] { background: var(--bubble-mine); }
        [class~="bg-white/20"] { background: rgba(255, 255, 255, 0.2); }
        [class~="bg-white/30"] { background: rgba(255, 255, 255, 0.3); }
        [class~="bg-white/10"] { background: rgba(255, 255, 255, 0.1); }
        [class~="bg-brand/5"] { background: rgba(7, 94, 84, 0.05); }
        [class~="bg-black/5"] { background: rgba(0, 0, 0, 0.05); }
        [class~="bg-black/30"] { background: var(--overlay-soft); }
        [class~="bg-black/50"] { background: var(--overlay-medium); }
        [class~="bg-black/85"] { background: var(--overlay-strong); }
        [class~="text-white/80"] { color: rgba(255, 255, 255, 0.8); }
        [class~="tracking-[0.2em]"] { letter-spacing: 0.2em; }
        [class~="tracking-[0.3em]"] { letter-spacing: 0.3em; }
        [class~="text-[10px]"] { font-size: 10px; }
        [class~="py-0.5"] { padding-top: 0.125rem; padding-bottom: 0.125rem; }
        [class~="py-1"] { padding-top: 0.25rem; padding-bottom: 0.25rem; }
        [class~="py-2"] { padding-top: 0.5rem; padding-bottom: 0.5rem; }
        [class~="py-2.5"] { padding-top: 0.625rem; padding-bottom: 0.625rem; }
        [class~="py-3"] { padding-top: 0.75rem; padding-bottom: 0.75rem; }
        [class~="py-3.5"] { padding-top: 0.875rem; padding-bottom: 0.875rem; }
        [class~="px-2"] { padding-left: 0.5rem; padding-right: 0.5rem; }
        [class~="px-3"] { padding-left: 0.75rem; padding-right: 0.75rem; }
        [class~="px-4"] { padding-left: 1rem; padding-right: 1rem; }
        [class~="p-2"] { padding: 0.5rem; }
        [class~="p-4"] { padding: 1rem; }
        [class~="p-6"] { padding: 1.5rem; }
        [class~="mt-1"] { margin-top: 0.25rem; }
        [class~="mt-2"] { margin-top: 0.5rem; }
        [class~="mt-4"] { margin-top: 1rem; }
        [class~="mb-0.5"] { margin-bottom: 0.125rem; }
        [class~="mb-1"] { margin-bottom: 0.25rem; }

        [class~="hover:bg-brand-light"]:hover { background: var(--brand-light); }
        [class~="hover:bg-white/30"]:hover { background: rgba(255, 255, 255, 0.3); }
        [class~="active:bg-white/10"]:active { background: rgba(255, 255, 255, 0.1); }
        [class~="hover:bg-brand/5"]:hover { background: rgba(7, 94, 84, 0.05); }
        [class~="hover:bg-gray-50"]:hover { background: #f9fafb; }
        [class~="hover:bg-gray-200"]:hover { background: #e5e7eb; }
        [class~="active:bg-gray-300"]:active { background: #d1d5db; }
        [class~="hover:bg-black"]:hover { background: #000; }
        [class~="hover:bg-black/5"]:hover { background: rgba(0, 0, 0, 0.05); }
        [class~="hover:text-white"]:hover { color: #fff; }
        [class~="hover:text-gray-700"]:hover { color: #374151; }
        [class~="hover:opacity-90"]:hover { opacity: 0.9; }
        [class~="active:opacity-75"]:active { opacity: 0.75; }

        [class~="focus:border-brand"]:focus {
          border-color: var(--brand);
        }

        [class~="z-[180]"] { z-index: 180; }
        [class~="z-[200]"] { z-index: 200; }

        @media (min-width: 640px) {
          [class~="sm:flex-row"] { flex-direction: row; }
          [class~="sm:text-left"] { text-align: left; }
        }

        #sidebar { transform: translateX(100%); transition: transform 0.2s ease; }
        #sidebar.open { transform: translateX(0); }
        #overlay { display: none; }
        #overlay.open { display: flex; }
        #roomQrModal { display: none; }
        #roomQrModal.open { display: flex; }
        .md-content p + p { margin-top: 0.5rem; }
        .md-content ul, .md-content ol { margin: 0.5rem 0; padding-left: 1.25rem; }
        .md-content li + li { margin-top: 0.25rem; }
        .md-content a { color: #075e54; text-decoration: underline; }
        .md-content blockquote {
          border-left: 3px solid #99cfc7;
          margin: 0.5rem 0;
          padding-left: 0.75rem;
          color: #4b5563;
        }
        .md-content pre {
          background: rgba(15, 23, 42, 0.92);
          color: #f8fafc;
          border-radius: 0.75rem;
          margin: 0.5rem 0;
          overflow-x: auto;
          padding: 0.75rem;
        }
        .md-content code {
          background: rgba(15, 23, 42, 0.08);
          border-radius: 0.35rem;
          font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
          font-size: 0.85em;
          padding: 0.1rem 0.35rem;
        }
        .md-content pre code {
          background: transparent;
          padding: 0;
        }
        /* 滚动条美化 */
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #ccc; border-radius: 2px; }
      </style>
    </head>
    <body class="bg-gray-100 h-screen flex flex-col font-sans overflow-hidden">

      <!-- 连接状态栏 -->
      <div id="statusBar"
           class="text-center text-xs text-white py-0.5 px-2 bg-yellow-500 transition-colors duration-300">
        连接中...
      </div>

      <!-- 顶部栏 -->
      <header class="bg-brand text-white px-4 py-3 flex justify-between items-center shadow-md flex-shrink-0">
        <h1 class="text-lg font-semibold tracking-wide">LanShare</h1>
        <button id="deviceCount"
                onclick="toggleSidebar()"
                class="bg-white/20 hover:bg-white/30 active:bg-white/10
                       text-sm px-3 py-1 rounded-full transition-colors">
          0 在线
        </button>
      </header>

      <section class="bg-white border-b border-gray-200 px-4 py-3 flex flex-col gap-3 shadow-sm">
        <div class="flex flex-wrap gap-2 items-center justify-between">
          <div>
            <p class="text-xs uppercase tracking-[0.2em] text-gray-400">当前会话</p>
            <p id="roomLabel" class="text-sm font-semibold text-gray-800">#{assigns.room_label}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button onclick="createRoom()"
                    class="px-3 py-2 rounded-full bg-brand text-white text-sm hover:bg-brand-light transition-colors">
              创建房间
            </button>
            <button id="showQrButton"
                    onclick="openQrModal()"
                    class="px-3 py-2 rounded-full border border-brand text-brand text-sm hover:bg-brand/5 transition-colors #{if room_code, do: "", else: "hidden"}">
              显示二维码
            </button>
            <a id="leaveRoomLink"
               href="/"
               class="px-3 py-2 rounded-full border border-gray-300 text-gray-600 text-sm hover:bg-gray-50 transition-colors #{if room_code, do: "", else: "hidden"}">
              返回大厅
            </a>
          </div>
        </div>

        <form action="/join" method="post" class="flex flex-col sm:flex-row gap-2">
          <input id="roomInput"
                 name="code"
                 type="text"
                 inputmode="latin"
                 maxlength="4"
                 placeholder="输入 4 位房间码"
                 value="#{room_code || ""}"
                 class="flex-1 border border-gray-300 focus:border-brand rounded-2xl px-4 py-2 text-sm outline-none uppercase tracking-[0.3em] text-center sm:text-left">
          <button type="submit"
                  class="px-4 py-2 rounded-2xl bg-gray-900 text-white text-sm hover:bg-black transition-colors">
            加入房间
          </button>
        </form>

        <p id="roomHint" class="text-xs text-gray-500">
          #{if room_code, do: "当前房间链接可扫码分享，消息与在线设备仅在该房间可见。", else: "未加入房间时处于大厅。可输入房间码加入，或直接创建新的私密房间。"}
        </p>
      </section>

      <!-- 设备侧边栏（固定右侧抽屉） -->
      <aside id="sidebar"
             class="fixed top-0 right-0 bottom-0 w-64 bg-white shadow-2xl z-50 flex flex-col">
        <div class="bg-brand text-white px-4 py-3.5 flex justify-between items-center flex-shrink-0">
          <h2 class="text-base font-medium">在线设备</h2>
          <button onclick="toggleSidebar()"
                  class="text-white/80 hover:text-white text-2xl leading-none">&times;</button>
        </div>
        <div id="deviceList" class="flex-1 overflow-y-auto divide-y divide-gray-100"></div>
      </aside>
      <!-- 侧边栏遮罩 -->
      <div id="sidebarMask"
           onclick="toggleSidebar()"
           class="hidden fixed inset-0 bg-black/30 z-40"></div>

      <!-- 消息列表 -->
      <main id="messages"
            class="flex-1 overflow-y-auto px-4 py-3 flex flex-col gap-2 min-h-0">
      </main>

      <!-- 输入区 -->
      <footer class="bg-white border-t border-gray-200 px-4 py-2.5 flex gap-2 items-end flex-shrink-0">
        <button id="imageSendButton"
                onclick="document.getElementById('imageInput').click()"
                title="选择本地图片，或直接粘贴图片"
                class="w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 active:bg-gray-300
                        flex items-center justify-center text-xl flex-shrink-0 transition-colors">
          &#128247;
        </button>
        <input type="file" id="imageInput" class="hidden" accept="image/*"
                onchange="handleImageSelect(event)">
        <button id="fileSendButton"
                onclick="document.getElementById('transferFileInput').click()"
                class="w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 active:bg-gray-300
                       flex items-center justify-center text-xl flex-shrink-0 transition-colors">
          &#128206;
        </button>
        <input type="file" id="transferFileInput" class="hidden" onchange="handleFileSelect(event)">
        <textarea id="textInput" rows="1"
              placeholder="输入消息… (Shift+Enter 换行，Ctrl+V 粘贴图片)"
                  onkeydown="handleKeyDown(event)"
                  oninput="autoResize(this)"
                  class="flex-1 border border-gray-300 focus:border-brand rounded-2xl
                         px-4 py-2 text-sm resize-none max-h-28 outline-none
                         font-sans leading-relaxed transition-colors"></textarea>
        <button onclick="sendText()"
                class="w-10 h-10 rounded-full bg-brand hover:bg-brand-light active:opacity-75
                       flex items-center justify-center text-white text-lg flex-shrink-0 transition-colors">
          &#9654;
        </button>
      </footer>

      <!-- 图片全屏预览 -->
      <div id="overlay"
           onclick="closeOverlay()"
           class="fixed inset-0 bg-black/85 z-[200] items-center justify-center cursor-pointer">
        <img id="overlayImg" src="" alt="预览"
             class="max-w-[95vw] max-h-[95vh] object-contain rounded-lg shadow-2xl">
      </div>

      <div id="roomQrModal"
           class="fixed inset-0 bg-black/50 z-[180] items-center justify-center px-4"
           onclick="closeQrModal(event)">
        <div class="w-full max-w-sm bg-white rounded-3xl shadow-2xl p-6" onclick="event.stopPropagation()">
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-xs uppercase tracking-[0.2em] text-gray-400">房间分享</p>
              <h2 id="qrRoomLabel" class="text-lg font-semibold text-gray-900">#{assigns.room_label}</h2>
            </div>
            <button onclick="closeQrModal()" class="text-2xl leading-none text-gray-400 hover:text-gray-700">&times;</button>
          </div>
          <div class="mt-4 bg-gray-50 rounded-2xl p-4 flex items-center justify-center min-h-64">
            <img id="roomQrImage" src="" alt="房间二维码" class="w-64 h-64 rounded-xl bg-white p-2 shadow-sm hidden">
            <p id="roomQrPlaceholder" class="text-sm text-gray-500">正在生成二维码...</p>
          </div>
          <div class="mt-4 flex gap-2">
            <input id="shareLink" readonly class="flex-1 border border-gray-300 rounded-2xl px-4 py-2 text-xs text-gray-600 bg-gray-50 outline-none">
            <button onclick="copyShareLink()" class="px-4 py-2 rounded-2xl bg-gray-900 text-white text-sm hover:bg-black transition-colors">
              复制链接
            </button>
          </div>
        </div>
      </div>

      <script>
        let ws;
        let myName = '';
        let currentRoomCode = #{Jason.encode!(room_code)};
        let reconnectTimer;
        let shouldStickToBottom = true;
        let nextLocalUploadId = 1;

        const localFileUploads = new Map();

        const messagesEl = document.getElementById('messages');

        messagesEl.addEventListener('scroll', () => {
          shouldStickToBottom =
            messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight < 32;
        });

        document.addEventListener('paste', handlePaste);

        /* ── WebSocket ── */
        function connect() {
          const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          const wsUrl = new URL(`${proto}//${location.host}/ws`);
          if (currentRoomCode) wsUrl.searchParams.set('room', currentRoomCode);
          ws = new WebSocket(wsUrl);

          ws.onopen = () => {
            setStatus('已连接', 'bg-green-500');
            clearTimeout(reconnectTimer);
          };
          ws.onclose = () => {
            setStatus('连接断开，正在重连…', 'bg-red-500');
            reconnectTimer = setTimeout(connect, 2000);
          };
          ws.onerror = () => ws.close();
          ws.onmessage = e => handleMessage(JSON.parse(e.data));
        }

        function setStatus(text, colorClass) {
          const el = document.getElementById('statusBar');
          el.textContent = text;
          el.className = `text-center text-xs text-white py-0.5 px-2 transition-colors duration-300 ${colorClass}`;
        }

        /* ── 消息处理 ── */
        function handleMessage(msg) {
          switch (msg.type) {
            case 'welcome':
              myName = msg.device_name || '';
              if (Object.prototype.hasOwnProperty.call(msg, 'room_code')) {
                currentRoomCode = msg.room_code;
                syncRoomUi();
              }
              if (msg.devices) updateDeviceList(msg.devices);
              break;
            case 'history':
              msg.messages.forEach(m => renderMessage(m));
              scrollToBottom();
              break;
            case 'file':
              resolveLocalFileUpload(msg.id);
              renderMessage(msg);
              scrollToBottom();
              break;
            case 'text':
            case 'image':
              renderMessage(msg);
              scrollToBottom();
              break;
            case 'system':
              renderSystem(msg.content);
              if (msg.devices) updateDeviceList(msg.devices);
              scrollToBottom();
              break;
          }
        }

        function renderMessage(msg) {
          const isMine = msg.sender === myName;
          const wrap = document.createElement('div');
          wrap.className = `flex ${isMine ? 'justify-end' : 'justify-start'}`;

          const bubble = document.createElement('div');
          bubble.className = [
            'max-w-[75%] rounded-xl px-3 py-2 text-sm leading-relaxed break-words shadow-sm',
            isMine ? 'bg-[#dcf8c6] text-gray-800' : 'bg-white text-gray-800'
          ].join(' ');

          if (msg.type === 'text') {
            const contentHtml = msg.content_html || `<p>${renderText(msg.content)}</p>`;
            bubble.innerHTML = `
              ${!isMine ? `<p class="text-xs font-semibold text-brand mb-0.5">${escapeHtml(msg.sender)}</p>` : ''}
              <div class="md-content">${contentHtml}</div>
              <div class="mt-2 flex items-center justify-end gap-2 text-[10px] text-gray-400">
                <button type="button"
                        class="copy-message rounded-full border border-gray-300 px-2 py-0.5 text-[10px] text-gray-500 hover:bg-black/5 transition-colors">
                  复制源码
                </button>
                <span>${formatTime(msg.timestamp)}</span>
              </div>
            `;

            bubble.querySelector('.copy-message').addEventListener('click', event => {
              copyMessageSource(msg.content, event.currentTarget);
            });
          } else if (msg.type === 'image') {
            bubble.innerHTML = `
              ${!isMine ? `<p class="text-xs font-semibold text-brand mb-1">${escapeHtml(msg.sender)}</p>` : ''}
              <img src="${msg.data}" alt="${escapeHtml(msg.filename)}"
                   onclick="openOverlay(this.src)"
                   class="max-w-full max-h-72 rounded-lg cursor-pointer hover:opacity-90 transition-opacity block">
              <p class="text-[10px] text-gray-400 text-right mt-1">${formatTime(msg.timestamp)}</p>
            `;
          } else if (msg.type === 'file') {
            bubble.innerHTML = `
              ${!isMine ? `<p class="text-xs font-semibold text-brand mb-1">${escapeHtml(msg.sender)}</p>` : ''}
              <div class="flex items-start gap-2">
                <div class="w-10 h-10 rounded-lg bg-white/30 flex items-center justify-center text-lg flex-shrink-0">&#128206;</div>
                <div class="flex-1 break-words">
                  <p class="font-medium">${escapeHtml(msg.filename)}</p>
                  <p class="text-xs text-gray-500 mt-1">${formatFileSize(msg.size)} · ${escapeHtml(msg.content_type || 'application/octet-stream')}</p>
                </div>
              </div>
              <div class="mt-2 flex items-center justify-between gap-2 text-[10px] text-gray-400">
                <span>${formatTime(msg.timestamp)}</span>
                <button type="button"
                        data-download-url="${escapeAttribute(msg.download_url)}"
                        data-download-filename="${escapeAttribute(msg.filename)}"
                        class="download-file rounded-full border border-gray-300 px-2 py-0.5 text-[10px] text-gray-500 hover:bg-black/5 transition-colors">
                  下载文件
                </button>
              </div>
            `;

            bubble.querySelector('.download-file').addEventListener('click', event => {
              startFileDownload(
                event.currentTarget.dataset.downloadUrl,
                event.currentTarget.dataset.downloadFilename,
                event.currentTarget
              );
            });
          }

          wrap.appendChild(bubble);
          messagesEl.appendChild(wrap);
        }

        function renderSystem(text) {
          const div = document.createElement('div');
          div.className = 'self-center text-xs text-gray-500 bg-black/5 rounded-full px-3 py-0.5';
          div.textContent = text;
          messagesEl.appendChild(div);
        }

        function updateDeviceList(devices) {
          document.getElementById('deviceCount').textContent = `${devices.length} 在线`;
          document.getElementById('deviceList').innerHTML = devices.map(d => `
            <div class="flex items-center gap-2 px-4 py-2.5 text-sm text-gray-700">
              <span class="w-2 h-2 rounded-full bg-green-400 flex-shrink-0"></span>
              <span class="truncate">${escapeHtml(d)}${d === myName ? ' <span class="text-gray-400 text-xs">(我)</span>' : ''}</span>
            </div>
          `).join('');
        }

        function syncRoomUi() {
          const roomLabel = currentRoomCode || '大厅';
          document.getElementById('roomLabel').textContent = roomLabel;
          document.getElementById('qrRoomLabel').textContent = roomLabel;
          document.getElementById('roomInput').value = currentRoomCode || '';
          document.getElementById('showQrButton').classList.toggle('hidden', !currentRoomCode);
          document.getElementById('leaveRoomLink').classList.toggle('hidden', !currentRoomCode);
          document.getElementById('roomHint').textContent = currentRoomCode
            ? '当前房间链接可扫码分享，消息与在线设备仅在该房间可见。'
            : '未加入房间时处于大厅。可输入房间码加入，或直接创建新的私密房间。';

          const shareLink = currentRoomCode
            ? `${location.origin}/r/${currentRoomCode}`
            : location.origin + '/';

          document.getElementById('shareLink').value = shareLink;
        }

        function createRoom() {
          location.href = '/room/new';
        }

        function openQrModal() {
          if (!currentRoomCode) return;
          document.getElementById('roomQrModal').classList.add('open');
          renderQrCode();
        }

        function closeQrModal(event) {
          if (event && event.target !== event.currentTarget) return;
          document.getElementById('roomQrModal').classList.remove('open');
        }

        function renderQrCode() {
          const image = document.getElementById('roomQrImage');
          const placeholder = document.getElementById('roomQrPlaceholder');

          placeholder.textContent = '正在生成二维码...';
          placeholder.classList.remove('hidden');
          image.classList.add('hidden');

          image.onload = () => {
            image.classList.remove('hidden');
            placeholder.classList.add('hidden');
          };

          image.onerror = () => {
            placeholder.textContent = '二维码生成失败';
            image.classList.add('hidden');
          };

          image.src = currentRoomCode ? LanShareRoom.qrcodePath(currentRoomCode) : '';
        }

        async function copyShareLink() {
          const input = document.getElementById('shareLink');

          try {
            await navigator.clipboard.writeText(input.value);
          } catch (_error) {
            input.select();
            document.execCommand('copy');
            input.blur();
          }
        }

        async function copyMessageSource(source, button) {
          const originalText = button.textContent;

          try {
            await navigator.clipboard.writeText(source);
          } catch (_error) {
            const helper = document.createElement('textarea');
            helper.value = source;
            helper.setAttribute('readonly', 'readonly');
            helper.style.position = 'fixed';
            helper.style.opacity = '0';
            document.body.appendChild(helper);
            helper.select();
            document.execCommand('copy');
            document.body.removeChild(helper);
          }

          button.textContent = '已复制';
          window.setTimeout(() => {
            button.textContent = originalText;
          }, 1200);
        }

        function createLocalFileUpload(file) {
          const localId = String(nextLocalUploadId++);
          const wrap = document.createElement('div');
          wrap.className = 'flex justify-end';

          const bubble = document.createElement('div');
          bubble.className = 'max-w-[75%] rounded-xl px-3 py-2 text-sm leading-relaxed break-words shadow-sm bg-[#dcf8c6] text-gray-800';
          bubble.innerHTML = `
            <div class="flex items-start gap-2">
              <div class="w-10 h-10 rounded-lg bg-white/30 flex items-center justify-center text-lg flex-shrink-0">&#128206;</div>
              <div class="flex-1 break-words">
                <p class="font-medium">${escapeHtml(file.name || '未命名文件')}</p>
                <p class="text-xs text-gray-500 mt-1">${formatFileSize(file.size)}</p>
              </div>
            </div>
            <div class="mt-2 flex items-center justify-between gap-2 text-[10px] text-gray-400">
              <span class="upload-status">正在上传...</span>
              <button type="button"
                      class="retry-upload hidden rounded-full border border-gray-300 px-2 py-0.5 text-[10px] text-gray-500 hover:bg-black/5 transition-colors">
                重试
              </button>
            </div>
          `;

          wrap.appendChild(bubble);
          messagesEl.appendChild(wrap);

          const upload = {
            id: localId,
            file,
            fileKey: fileFingerprint(file),
            el: wrap,
            statusEl: bubble.querySelector('.upload-status'),
            retryButton: bubble.querySelector('.retry-upload'),
            inFlight: false,
            uploadedMeta: null,
            serverId: null
          };

          upload.retryButton.addEventListener('click', () => retryLocalFileUpload(localId));
          localFileUploads.set(localId, upload);
          scrollToBottom();

          return upload;
        }

        async function retryLocalFileUpload(localId) {
          const upload = localFileUploads.get(localId);
          if (!upload || upload.inFlight) return;

          if (upload.uploadedMeta) {
            try {
              sendUploadedFileMessage(upload, upload.uploadedMeta);
            } catch (error) {
              markFileUploadFailed(upload, error.message || '文件发送失败');
            }
          } else {
            await startFileUpload(upload);
          }
        }

        /* ── 发送 ── */
        function sendText() {
          const input = document.getElementById('textInput');
          const text = input.value;
          // 不 trim，保留用户的首尾空白；但全空白不发
          if (!text.trim() || !ws || ws.readyState !== WebSocket.OPEN) return;
          ws.send(JSON.stringify({ type: 'text', content: text }));
          input.value = '';
          input.style.height = 'auto';
        }

        function handleImageSelect(event) {
          const file = event.target.files[0];
          if (!file) return;
          event.target.value = '';
          void sendImageFile(file);
        }

        function handlePaste(event) {
          const clipboardFiles = extractClipboardImageFiles(event.clipboardData);

          if (clipboardFiles.length === 0) {
            return;
          }

          event.preventDefault();
          void sendClipboardImages(clipboardFiles);
        }

        async function sendClipboardImages(files) {
          for (const [index, file] of files.entries()) {
            const clipboardImage = createClipboardImageFile(file, index);
            await sendImageFile(clipboardImage);
          }
        }

        async function sendImageFile(file) {
          if (file.size > 5 * 1024 * 1024) {
            alert('图片大小不能超过 5MB');
            return;
          }

          const dataUrl = await readFileAsDataUrl(file);

          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'image', data: dataUrl, filename: file.name || 'image' }));
          }
        }

        function readFileAsDataUrl(file) {
          return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = event => resolve(event.target.result);
            reader.onerror = () => reject(new Error('图片读取失败'));
            reader.readAsDataURL(file);
          });
        }

        function extractClipboardImageFiles(clipboardData) {
          if (!clipboardData) {
            return [];
          }

          const files = Array.from(clipboardData.items || [])
            .filter(item => item.kind === 'file' && item.type && item.type.startsWith('image/'))
            .map(item => item.getAsFile())
            .filter(Boolean);

          if (files.length > 0) {
            return files;
          }

          return Array.from(clipboardData.files || [])
            .filter(file => file.type && file.type.startsWith('image/'));
        }

        function createClipboardImageFile(file, index) {
          if (file.name) {
            return file;
          }

          const extension = guessImageExtension(file.type);
          const filename = `pasted-image-${Date.now()}-${index + 1}.${extension}`;

          return new File([file], filename, {
            type: file.type || 'image/png',
            lastModified: Date.now()
          });
        }

        function guessImageExtension(mimeType) {
          switch (mimeType) {
            case 'image/jpeg':
              return 'jpg';
            case 'image/gif':
              return 'gif';
            case 'image/webp':
              return 'webp';
            case 'image/bmp':
              return 'bmp';
            case 'image/svg+xml':
              return 'svg';
            case 'image/png':
            default:
              return 'png';
          }
        }

        async function handleFileSelect(event) {
          const file = event.target.files[0];
          event.target.value = '';
          if (!file) return;

          if (!currentRoomCode) {
            alert('请先加入房间，再发送文件');
            return;
          }

          if (file.size > 1024 * 1024 * 1024) {
            alert('文件大小不能超过 1GB');
            return;
          }

          if (findInFlightUpload(file)) {
            return;
          }

          const upload = createLocalFileUpload(file);
          await startFileUpload(upload);
        }

        async function startFileUpload(upload) {
          upload.inFlight = true;
          upload.retryButton.classList.add('hidden');
          upload.statusEl.textContent = '正在上传...';
          setFileUploadButtonState(hasInFlightUpload());

          const formData = new FormData();
          formData.append('room', currentRoomCode);
          formData.append('file', upload.file);

          try {
            const response = await fetch('/upload/file', {
              method: 'POST',
              body: formData
            });

            let payload = {};

            try {
              payload = await response.json();
            } catch (_error) {
              payload = {};
            }

            if (!response.ok) {
              throw new Error(payload.error || '文件上传失败');
            }

            upload.uploadedMeta = payload;
            upload.serverId = payload.id;
            sendUploadedFileMessage(upload, payload);
          } catch (error) {
            markFileUploadFailed(upload, error.message || '文件上传失败');
          } finally {
            upload.inFlight = false;
            setFileUploadButtonState(hasInFlightUpload());
          }
        }

        function sendUploadedFileMessage(upload, metadata) {
          if (!ws || ws.readyState !== WebSocket.OPEN) {
            throw new Error('上传已完成，但消息发送失败，请重试');
          }

          upload.statusEl.textContent = '上传完成，正在发送...';
          upload.retryButton.classList.add('hidden');
          upload.serverId = metadata.id;

          ws.send(JSON.stringify({
            type: 'file',
            id: metadata.id,
            filename: metadata.filename,
            size: metadata.size,
            content_type: metadata.content_type,
            download_url: metadata.download_url
          }));
        }

        function resolveLocalFileUpload(fileId) {
          for (const upload of localFileUploads.values()) {
            if (upload.serverId === fileId) {
              upload.el.remove();
              localFileUploads.delete(upload.id);
              break;
            }
          }
        }

        function markFileUploadFailed(upload, message) {
          upload.inFlight = false;
          upload.statusEl.textContent = message;
          upload.retryButton.classList.remove('hidden');
          setFileUploadButtonState(hasInFlightUpload());
        }

        function hasInFlightUpload() {
          return Array.from(localFileUploads.values()).some(upload => upload.inFlight);
        }

        function findInFlightUpload(file) {
          const key = fileFingerprint(file);
          return Array.from(localFileUploads.values()).find(upload => upload.inFlight && upload.fileKey === key);
        }

        function fileFingerprint(file) {
          return [file.name, file.size, file.lastModified].join(':');
        }

        function setFileUploadButtonState(disabled) {
          const button = document.getElementById('fileSendButton');
          button.disabled = disabled;
          button.classList.toggle('opacity-50', disabled);
        }

        function handleKeyDown(event) {
          // Enter 发送，Shift+Enter 换行
          if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            sendText();
          }
        }

        function autoResize(el) {
          el.style.height = 'auto';
          el.style.height = Math.min(el.scrollHeight, 112) + 'px';
        }

        /* ── 侧边栏 ── */
        function toggleSidebar() {
          const sidebar = document.getElementById('sidebar');
          const mask = document.getElementById('sidebarMask');
          const isOpen = sidebar.classList.toggle('open');
          mask.classList.toggle('hidden', !isOpen);
        }

        /* ── 图片预览 ── */
        function openOverlay(src) {
          document.getElementById('overlayImg').src = src;
          document.getElementById('overlay').classList.add('open');
        }
        function closeOverlay() {
          document.getElementById('overlay').classList.remove('open');
        }

        /* ── 工具函数 ── */
        function scrollToBottom() {
          if (!shouldStickToBottom) return;
          messagesEl.scrollTop = messagesEl.scrollHeight;
        }

        function escapeHtml(text) {
          const d = document.createElement('div');
          d.textContent = text;
          return d.innerHTML;
        }

        function escapeAttribute(text) {
          return escapeHtml(text || '');
        }

        // 仅作为旧消息的后备渲染，正常文本消息优先使用服务端生成的 Markdown HTML
        function renderText(text) {
          return escapeHtml(text).replaceAll(String.fromCharCode(10), '<br>');
        }

        function formatTime(iso) {
          if (!iso) return '';
          return new Date(iso).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
        }

        function formatFileSize(bytes) {
          if (!Number.isFinite(bytes) || bytes < 0) return '未知大小';
          if (bytes < 1024) return `${bytes} B`;

          const units = ['KB', 'MB', 'GB', 'TB'];
          let value = bytes / 1024;
          let unitIndex = 0;

          while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024;
            unitIndex += 1;
          }

          return `${value >= 10 ? value.toFixed(0) : value.toFixed(1)} ${units[unitIndex]}`;
        }

        function startFileDownload(downloadUrl, filename, button) {
          const originalText = button.textContent;
          const link = document.createElement('a');
          link.href = downloadUrl;
          link.download = filename;
          link.rel = 'noopener';
          link.target = '_blank';

          button.textContent = '处理中...';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);

          window.setTimeout(() => {
            button.textContent = originalText;
          }, 800);
        }

        // 心跳
        setInterval(() => {
          if (ws && ws.readyState === WebSocket.OPEN)
            ws.send(JSON.stringify({ type: 'ping' }));
        }, 30000);

        const LanShareRoom = {
          qrcodePath(roomCode) {
            return `/r/${roomCode}/qrcode.svg`;
          }
        };

        syncRoomUi();
        connect();
      </script>
    </body>
    </html>
    """
  end
end
