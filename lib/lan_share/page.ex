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
          height: 100dvh;
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

        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.4; }
        }
        .animate-pulse { animation: pulse 1.5s ease-in-out infinite; }

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
        .h-screen { height: 100vh; height: 100dvh; }
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

        [class~="placeholder-white/50"]::placeholder { color: rgba(255,255,255,0.5); }

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
        #filePreviewModal { display: none; }
        #filePreviewModal.open { display: flex; }
        #filePreviewSandboxWrap { display: none; }
        #filePreviewSandboxWrap.open { display: block; }
        #filePreviewSourceWrap { display: none; }
        #filePreviewSourceWrap.open { display: block; }
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

      <!-- 统一顶部栏 -->
      <header class="topbar bg-brand text-white px-3 py-1.5 flex flex-col flex-shrink-0 shadow-md">
        <div class="flex items-center gap-3">
          <!-- Logo + 房间信息 -->
          <h1 class="text-base font-semibold leading-none flex-shrink-0">LanShare</h1>
          <span class="topbar-sep hidden">·</span>
          <div class="flex items-center gap-3 min-w-0 flex-1">
            <span id="roomLabel" class="text-sm text-white/80 truncate">#{assigns.room_label}</span>
            <div id="joinToggle" class="flex items-center gap-1 cursor-pointer select-none opacity-70 hover:opacity-100 transition-opacity" onclick="toggleJoinSection()">
              <span class="text-[10px] text-white/80">加入</span>
              <span id="joinToggleIcon" class="text-[10px] text-white/60">▶</span>
            </div>
          </div>
          <!-- 按钮组 -->
          <div class="flex items-center gap-1 flex-shrink-0">
            <button onclick="createRoom()"
                    class="px-2 py-1 rounded-full bg-white/20 hover:bg-white/30 text-xs font-medium transition-colors">
              新建
            </button>
            <button id="showQrButton"
                    onclick="openQrModal()"
                    class="px-2 py-1 rounded-full bg-white/20 hover:bg-white/30 text-xs font-medium transition-colors #{if room_code, do: "", else: "hidden"}">
              QR
            </button>
            <a id="leaveRoomLink"
               href="/"
               class="px-2 py-1 rounded-full bg-white/20 hover:bg-white/30 text-xs font-medium transition-colors #{if room_code, do: "", else: "hidden"}">
              大厅
            </a>
            <button id="deviceCount"
                    onclick="toggleSidebar()"
                    class="px-2 py-1 rounded-full bg-white/20 hover:bg-white/30 text-xs flex items-center gap-1 transition-colors">
              <span id="connDot" class="inline-block w-2 h-2 rounded-full bg-yellow-400"></span>
              <span id="connLabel">…</span>
            </button>
          </div>
        </div>
        <!-- 加入房间展开区 -->
        <div id="joinSection" class="hidden border-t border-white/20 mt-1.5 pt-1.5 pb-0.5">
          <form action="/join" method="post" class="flex items-center gap-2">
            <input id="roomInput"
                   name="code"
                   type="text"
                   inputmode="latin"
                   maxlength="4"
                   placeholder="4位房间码"
                   value="#{room_code || ""}"
                   class="w-24 border border-white/30 bg-white/10 focus:bg-white/20 rounded-xl px-3 py-1 text-sm outline-none uppercase tracking-[0.3em] text-center text-white placeholder-white/50">
            <button type="submit"
                    class="px-2 py-1 rounded-full bg-white text-brand text-xs font-medium hover:bg-gray-100 transition-colors">
              加入
            </button>
            <p class="text-[10px] text-white/60 truncate flex-1">
              #{if room_code, do: "消息僅房間可見", else: "输入房间码加入"}
            </p>
          </form>
        </div>
      </header>

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

      <div id="filePreviewModal"
           class="fixed inset-0 bg-black/50 z-[180] items-center justify-center px-4"
           onclick="closeFilePreview(event)">
        <div class="w-full max-w-4xl max-h-[85vh] bg-white rounded-3xl shadow-2xl overflow-hidden flex flex-col" onclick="event.stopPropagation()">
          <div class="px-5 py-4 border-b border-gray-200 flex items-start justify-between gap-4">
            <div class="min-w-0">
              <p class="text-xs uppercase tracking-[0.2em] text-gray-400">源码预览</p>
              <h2 id="filePreviewTitle" class="text-base font-semibold text-gray-900 break-all">文件内容</h2>
            </div>
            <button onclick="closeFilePreview()" class="text-2xl leading-none text-gray-400 hover:text-gray-700">&times;</button>
          </div>
          <div class="px-5 py-3 border-b border-gray-100 flex items-center justify-between gap-3 text-xs text-gray-500">
            <span id="filePreviewMeta">加载中...</span>
            <div class="flex items-center gap-2">
              <button id="filePreviewSourceTab"
                      type="button"
                      class="rounded-full border border-gray-300 px-3 py-1 text-xs text-gray-600 hover:bg-black/5 transition-colors">
                源码
              </button>
              <button id="filePreviewRenderTab"
                      type="button"
                      class="hidden rounded-full border border-gray-300 px-3 py-1 text-xs text-gray-600 hover:bg-black/5 transition-colors">
                安全预览
              </button>
              <button id="copyFilePreviewButton"
                      type="button"
                      class="rounded-full border border-gray-300 px-3 py-1 text-xs text-gray-600 hover:bg-black/5 transition-colors">
                复制源码
              </button>
            </div>
          </div>
          <div class="flex-1 overflow-hidden bg-gray-950">
            <div id="filePreviewSourceWrap" class="open h-full overflow-auto bg-gray-950">
              <pre id="filePreviewContent" class="m-0 min-h-full p-5 text-sm leading-relaxed text-gray-100 whitespace-pre-wrap break-words"></pre>
            </div>
            <div id="filePreviewSandboxWrap" class="h-full bg-white">
              <iframe id="filePreviewSandbox"
                      title="HTML 安全预览"
                      sandbox
                      referrerpolicy="no-referrer"
                      style="border:0; width:100%; height:100%; background:#fff;"></iframe>
            </div>
          </div>
          <div class="px-5 py-3 border-t border-gray-100 flex items-center justify-between gap-3 text-xs text-gray-500 bg-white">
            <span>支持 Esc、右上角关闭、点击遮罩关闭</span>
            <button type="button"
                    onclick="closeFilePreview()"
                    class="rounded-full bg-gray-900 px-4 py-2 text-xs text-white hover:bg-black transition-colors">
              关闭
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
        const LONG_TEXT_CHAR_THRESHOLD = 4000;
        const LONG_TEXT_BYTE_THRESHOLD = 12 * 1024;
        const HTML_SNIPPET_CHAR_THRESHOLD = 1200;
        const LONG_TEXT_FILENAME_PREFIX = 'long-message';

        const localFileUploads = new Map();
        const previewCache = new Map();
        let currentFilePreviewState = null;

        const messagesEl = document.getElementById('messages');

        messagesEl.addEventListener('scroll', () => {
          shouldStickToBottom =
            messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight < 32;
        });

        document.addEventListener('paste', handlePaste);
        document.addEventListener('keydown', handleGlobalKeyDown);

        /* ── WebSocket ── */
        function connect() {
          const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          const wsUrl = new URL(`${proto}//${location.host}/ws`);
          if (currentRoomCode) wsUrl.searchParams.set('room', currentRoomCode);
          ws = new WebSocket(wsUrl);

          ws.onopen = () => {
            setConnState(true);
            clearTimeout(reconnectTimer);
          };
          ws.onclose = () => {
            setConnState(false);
            reconnectTimer = setTimeout(connect, 2000);
          };
          ws.onerror = () => ws.close();
          ws.onmessage = e => handleMessage(JSON.parse(e.data));
        }

        let _connected = false;

        function setConnState(connected) {
          _connected = connected;
          const dot = document.getElementById('connDot');
          dot.className = `inline-block w-2 h-2 rounded-full ${connected ? 'bg-green-400' : 'bg-red-400 animate-pulse'}`;
          updateConnLabel();
        }

        function updateConnLabel() {
          const label = document.getElementById('connLabel');
          if (!_connected) {
            label.textContent = '重连中…';
          } else {
            label.textContent = _lastDeviceCount !== null ? `${_lastDeviceCount} 在线` : '已连接';
          }
        }

        let _lastDeviceCount = null;

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

            bubble.querySelectorAll('.md-content a').forEach(a => {
              a.setAttribute('target', '_blank');
              a.setAttribute('rel', 'noopener');
            });
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
            const previewable = isPreviewableFileMessage(msg);
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
                <div class="flex items-center gap-2">
                  ${previewable ? `<button type="button"
                        data-copy-url="${escapeAttribute(msg.download_url)}"
                        data-copy-filename="${escapeAttribute(msg.filename)}"
                        data-copy-content-type="${escapeAttribute(msg.content_type || '')}"
                        class="copy-file-source rounded-full border border-gray-300 px-2 py-0.5 text-[10px] text-gray-500 hover:bg-black/5 transition-colors">
                    复制源码
                  </button>` : ''}
                  ${previewable ? `<button type="button"
                        data-preview-url="${escapeAttribute(msg.download_url)}"
                        data-preview-filename="${escapeAttribute(msg.filename)}"
                        data-preview-content-type="${escapeAttribute(msg.content_type || '')}"
                        class="preview-file rounded-full border border-gray-300 px-2 py-0.5 text-[10px] text-gray-500 hover:bg-black/5 transition-colors">
                    预览源码
                  </button>` : ''}
                  <button type="button"
                          data-download-url="${escapeAttribute(msg.download_url)}"
                          data-download-filename="${escapeAttribute(msg.filename)}"
                          class="download-file rounded-full border border-gray-300 px-2 py-0.5 text-[10px] text-gray-500 hover:bg-black/5 transition-colors">
                    下载文件
                  </button>
                </div>
              </div>
            `;

            const previewButton = bubble.querySelector('.preview-file');
            const copyButton = bubble.querySelector('.copy-file-source');

            if (copyButton) {
              copyButton.addEventListener('click', event => {
                void copyFileMessageSource(
                  event.currentTarget.dataset.copyUrl,
                  event.currentTarget.dataset.copyFilename,
                  event.currentTarget.dataset.copyContentType,
                  event.currentTarget
                );
              });
            }

            if (previewButton) {
              previewButton.addEventListener('click', event => {
                void openFilePreview(
                  event.currentTarget.dataset.previewUrl,
                  event.currentTarget.dataset.previewFilename,
                  event.currentTarget.dataset.previewContentType,
                  event.currentTarget
                );
              });
            }

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
          _lastDeviceCount = devices.length;
          updateConnLabel();
          document.getElementById('deviceList').innerHTML = devices.map(d => `
            <div class="flex items-center gap-2 px-4 py-2.5 text-sm text-gray-700">
              <span class="w-2 h-2 rounded-full bg-green-400 flex-shrink-0"></span>
              <span class="truncate">${escapeHtml(d)}${d === myName ? ' <span class="text-gray-400 text-xs">(我)</span>' : ''}</span>
            </div>
          `).join('');
        }

        function toggleJoinSection() {
          const section = document.getElementById('joinSection');
          const icon = document.getElementById('joinToggleIcon');
          const isHidden = section.classList.contains('hidden');

          if (isHidden) {
            section.classList.remove('hidden');
            icon.textContent = '▼';
            localStorage.setItem('joinSectionCollapsed', '0');
          } else {
            section.classList.add('hidden');
            icon.textContent = '▶';
            localStorage.setItem('joinSectionCollapsed', '1');
          }
        }

        (function() {
          const section = document.getElementById('joinSection');
          const icon = document.getElementById('joinToggleIcon');
          if (!section) return;

          if (localStorage.getItem('joinSectionCollapsed') === '1') {
            section.classList.add('hidden');
            if (icon) icon.textContent = '▶';
          } else {
            section.classList.remove('hidden');
            if (icon) icon.textContent = '▼';
          }
        })();

        function syncRoomUi() {
          const roomLabel = currentRoomCode || '大厅';
          document.getElementById('roomLabel').textContent = roomLabel;
          document.getElementById('qrRoomLabel').textContent = roomLabel;
          document.getElementById('roomInput').value = currentRoomCode || '';
          document.getElementById('showQrButton').classList.toggle('hidden', !currentRoomCode);
          document.getElementById('leaveRoomLink').classList.toggle('hidden', !currentRoomCode);

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

        function createLocalFileUpload(file, options = {}) {
          const localId = String(nextLocalUploadId++);
          const detailText = options.detailText || formatFileSize(file.size);
          const pendingText = options.pendingText || '正在上传...';
          const wrap = document.createElement('div');
          wrap.className = 'flex justify-end';

          const bubble = document.createElement('div');
          bubble.className = 'max-w-[75%] rounded-xl px-3 py-2 text-sm leading-relaxed break-words shadow-sm bg-[#dcf8c6] text-gray-800';
          bubble.innerHTML = `
            <div class="flex items-start gap-2">
              <div class="w-10 h-10 rounded-lg bg-white/30 flex items-center justify-center text-lg flex-shrink-0">&#128206;</div>
              <div class="flex-1 break-words">
                <p class="font-medium">${escapeHtml(file.name || '未命名文件')}</p>
                <p class="text-xs text-gray-500 mt-1">${escapeHtml(detailText)}</p>
              </div>
            </div>
            <div class="mt-2 flex items-center justify-between gap-2 text-[10px] text-gray-400">
              <span class="upload-status">${escapeHtml(pendingText)}</span>
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
            pendingText,
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

          if (shouldSendTextAsFile(text)) {
            void sendLongTextAsFile(text, input);
            return;
          }

          ws.send(JSON.stringify({ type: 'text', content: text }));
          input.value = '';
          input.style.height = 'auto';
        }

        function shouldSendTextAsFile(text) {
          if (!text || !text.trim()) {
            return false;
          }

          if (looksLikeHtmlDocument(text) && text.length >= HTML_SNIPPET_CHAR_THRESHOLD) {
            return true;
          }

          const byteLength = new TextEncoder().encode(text).length;
          return text.length >= LONG_TEXT_CHAR_THRESHOLD || byteLength >= LONG_TEXT_BYTE_THRESHOLD;
        }

        async function sendLongTextAsFile(text, input) {
          const descriptor = buildLongTextFile(text);
          const file = new File([text], descriptor.filename, {
            type: descriptor.contentType,
            lastModified: Date.now()
          });

          if (findInFlightUpload(file)) {
            return;
          }

          const upload = createLocalFileUpload(file, {
            detailText: `${descriptor.label} · ${formatFileSize(file.size)}`,
            pendingText: `内容较长，正在上传${descriptor.label}...`
          });

          input.value = '';
          input.style.height = 'auto';
          await startFileUpload(upload);
        }

        function buildLongTextFile(text) {
          const kind = detectLongTextFileKind(text);
          const timestamp = formatTimestampForFilename(Date.now());

          return {
            filename: `${LONG_TEXT_FILENAME_PREFIX}-${timestamp}.${kind.extension}`,
            contentType: kind.contentType,
            label: kind.label
          };
        }

        function detectLongTextFileKind(text) {
          if (looksLikeHtmlDocument(text)) {
            return {
              extension: 'html',
              contentType: 'text/html',
              label: 'HTML 文档'
            };
          }

          return {
            extension: 'md',
            contentType: 'text/markdown',
            label: 'Markdown 文档'
          };
        }

        function looksLikeHtmlDocument(text) {
          const sample = text.trim();

          if (!sample.startsWith('<')) {
            return false;
          }

          if (/<\!doctype\s+html/i.test(sample) || /<html[\s>]/i.test(sample)) {
            return true;
          }

          const structuralTagMatches = sample.match(/<(head|body|main|section|article|div|table|form|style|script|svg|header|footer|nav)[\s>]/gi) || [];
          const closingTagMatches = sample.match(new RegExp('<\\/[a-z][^>]*>', 'gi')) || [];

          return structuralTagMatches.length >= 2 && closingTagMatches.length >= 2;
        }

        function isPreviewableFileMessage(msg) {
          return isPreviewableTextType(msg.content_type, msg.filename);
        }

        function isPreviewableTextType(contentType, filename) {
          const normalizedType = (contentType || '').toLowerCase();
          const lowerName = (filename || '').toLowerCase();

          if (normalizedType.startsWith('text/')) {
            return true;
          }

          return ['.md', '.markdown', '.html', '.htm', '.txt', '.json', '.xml', '.csv', '.js', '.ts', '.css'].some(ext => lowerName.endsWith(ext));
        }

        async function openFilePreview(downloadUrl, filename, contentType, button) {
          if (!downloadUrl) {
            return;
          }

          const originalText = button ? button.textContent : '';

          try {
            if (button) {
              button.textContent = '加载中...';
            }

            const cacheKey = `${downloadUrl}|${contentType || ''}|${filename || ''}`;
            const source = await fetchPreviewSource(downloadUrl, filename, contentType);
            showFilePreview(filename, contentType, source);
          } catch (error) {
            alert(error.message || '文件预览失败');
          } finally {
            if (button) {
              button.textContent = originalText;
            }
          }
        }

        async function copyFileMessageSource(downloadUrl, filename, contentType, button) {
          if (!downloadUrl) {
            return;
          }

          const source = await fetchPreviewSource(downloadUrl, filename, contentType);
          await copyMessageSource(source || '', button);
        }

        async function fetchPreviewSource(downloadUrl, filename, contentType) {
          const cacheKey = `${downloadUrl}|${contentType || ''}|${filename || ''}`;
          let source = previewCache.get(cacheKey);

          if (typeof source === 'string') {
            return source;
          }

          const response = await fetch(downloadUrl, {
            headers: {
              'X-Requested-With': 'LanSharePreview'
            }
          });

          if (!response.ok) {
            throw new Error('文件预览失败');
          }

          source = await response.text();
          previewCache.set(cacheKey, source);
          return source;
        }

        function showFilePreview(filename, contentType, source) {
          const modal = document.getElementById('filePreviewModal');
          const title = document.getElementById('filePreviewTitle');
          const meta = document.getElementById('filePreviewMeta');
          const content = document.getElementById('filePreviewContent');
          const copyButton = document.getElementById('copyFilePreviewButton');
          const sourceTab = document.getElementById('filePreviewSourceTab');
          const renderTab = document.getElementById('filePreviewRenderTab');
          const sourceWrap = document.getElementById('filePreviewSourceWrap');
          const sandboxWrap = document.getElementById('filePreviewSandboxWrap');
          const sandbox = document.getElementById('filePreviewSandbox');
          const renderable = isHtmlPreviewType(contentType, filename);

          title.textContent = filename || '文件内容';
          meta.textContent = `${contentType || 'text/plain'} · ${formatFileSize(new TextEncoder().encode(source || '').length)}`;
          content.textContent = source || '';
          currentFilePreviewState = {
            filename,
            contentType,
            source,
            renderable
          };

          renderTab.classList.toggle('hidden', !renderable);
          renderTab.disabled = !renderable;

          if (renderable) {
            sandbox.srcdoc = source || '';
          } else {
            sandbox.srcdoc = '';
          }

          sourceTab.onclick = () => switchFilePreviewMode('source');
          renderTab.onclick = () => switchFilePreviewMode('render');
          copyButton.onclick = event => {
            copyMessageSource(source || '', event.currentTarget);
          };

          switchFilePreviewMode(renderable ? 'render' : 'source');
          modal.classList.add('open');
        }

        function closeFilePreview(event) {
          if (event && event.target !== event.currentTarget) return;
          document.getElementById('filePreviewModal').classList.remove('open');
          document.getElementById('filePreviewSandbox').srcdoc = '';
          currentFilePreviewState = null;
        }

        function switchFilePreviewMode(mode) {
          const sourceTab = document.getElementById('filePreviewSourceTab');
          const renderTab = document.getElementById('filePreviewRenderTab');
          const sourceWrap = document.getElementById('filePreviewSourceWrap');
          const sandboxWrap = document.getElementById('filePreviewSandboxWrap');
          const renderable = currentFilePreviewState && currentFilePreviewState.renderable;
          const useRender = mode === 'render' && renderable;

          sourceWrap.classList.toggle('open', !useRender);
          sandboxWrap.classList.toggle('open', useRender);
          sourceTab.classList.toggle('bg-gray-900', !useRender);
          sourceTab.classList.toggle('text-white', !useRender);
          renderTab.classList.toggle('bg-gray-900', useRender);
          renderTab.classList.toggle('text-white', useRender);
        }

        function isHtmlPreviewType(contentType, filename) {
          const normalizedType = (contentType || '').toLowerCase();
          const lowerName = (filename || '').toLowerCase();
          return normalizedType.includes('text/html') || lowerName.endsWith('.html') || lowerName.endsWith('.htm');
        }

        function handleGlobalKeyDown(event) {
          if (event.key === 'Escape') {
            closeFilePreview();
          }
        }

        function formatTimestampForFilename(value) {
          const date = new Date(value);
          const parts = [
            date.getFullYear(),
            String(date.getMonth() + 1).padStart(2, '0'),
            String(date.getDate()).padStart(2, '0'),
            String(date.getHours()).padStart(2, '0'),
            String(date.getMinutes()).padStart(2, '0'),
            String(date.getSeconds()).padStart(2, '0')
          ];

          return `${parts[0]}${parts[1]}${parts[2]}-${parts[3]}${parts[4]}${parts[5]}`;
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
          upload.statusEl.textContent = upload.pendingText || '正在上传...';
          setFileUploadButtonState(hasInFlightUpload());

          const formData = new FormData();
          formData.append('room', currentRoomCode || '_LOBBY');
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
