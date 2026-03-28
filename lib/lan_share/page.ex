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
      <script src="https://cdn.tailwindcss.com"></script>
      <script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.4/build/qrcode.min.js"></script>
      <script>
        tailwind.config = {
          theme: {
            extend: {
              colors: {
                brand: { DEFAULT: '#075e54', light: '#128c7e', bubble: '#dcf8c6' }
              }
            }
          }
        }
      </script>
      <style>
        /* 仅 Tailwind 无法直接表达的状态类 */
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
        <button onclick="document.getElementById('fileInput').click()"
                class="w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 active:bg-gray-300
                       flex items-center justify-center text-xl flex-shrink-0 transition-colors">
          &#128247;
        </button>
        <input type="file" id="fileInput" class="hidden" accept="image/*"
               onchange="handleImageSelect(event)">
        <textarea id="textInput" rows="1"
                  placeholder="输入消息… (Shift+Enter 换行)"
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

        const messagesEl = document.getElementById('messages');

        messagesEl.addEventListener('scroll', () => {
          shouldStickToBottom =
            messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight < 32;
        });

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
          const url = document.getElementById('shareLink').value;
          const image = document.getElementById('roomQrImage');
          const placeholder = document.getElementById('roomQrPlaceholder');

          placeholder.textContent = '正在生成二维码...';
          placeholder.classList.remove('hidden');
          image.classList.add('hidden');

          if (!window.QRCode) {
            placeholder.textContent = '二维码库加载失败';
            return;
          }

          QRCode.toDataURL(url, {
            errorCorrectionLevel: 'M',
            margin: 1,
            width: 240,
            color: {
              dark: '#075e54',
              light: '#ffffff'
            }
          }, (error, dataUrl) => {
            if (error) {
              placeholder.textContent = '二维码生成失败';
              return;
            }

            image.src = dataUrl;
            image.classList.remove('hidden');
            placeholder.classList.add('hidden');
          });
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
          if (file.size > 5 * 1024 * 1024) {
            alert('图片大小不能超过 5MB');
            event.target.value = '';
            return;
          }
          const reader = new FileReader();
          reader.onload = e => {
            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({ type: 'image', data: e.target.result, filename: file.name }));
            }
          };
          reader.readAsDataURL(file);
          event.target.value = '';
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

        // 仅作为旧消息的后备渲染，正常文本消息优先使用服务端生成的 Markdown HTML
        function renderText(text) {
          return escapeHtml(text).replaceAll(String.fromCharCode(10), '<br>');
        }

        function formatTime(iso) {
          if (!iso) return '';
          return new Date(iso).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
        }

        // 心跳
        setInterval(() => {
          if (ws && ws.readyState === WebSocket.OPEN)
            ws.send(JSON.stringify({ type: 'ping' }));
        }, 30000);

        syncRoomUi();
        connect();
      </script>
    </body>
    </html>
    """
  end
end
