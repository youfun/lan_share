#!/usr/bin/env elixir
# scripts/deploy.exs — 部署 LanShare 到 VPS / Google Cloud VM
#
# 用法:
#   elixir scripts/deploy.exs                              # 完整部署
#   elixir scripts/deploy.exs --rollback                   # 回滚到上一版本
#   elixir scripts/deploy.exs --config scripts/deploy.toml # 指定配置文件
#
# 首次部署前(可选):
#   cp .env.prod.example .env.prod  # 如有需要,填入 PORT / LAN_SHARE_DB / LAN_SHARE_UPLOAD_ROOT
#
# 重要约束:
#   - 必须在与目标机器相同的 OS + CPU 架构下构建(exqlite 是 NIF)。
#   - var/ 目录(SQLite + uploads)永久保留,部署不会清理。
#   - 历史版本仅保留 1 个;连续 --rollback 两次会报错。
#   - 启用 [caddy] 时会自动用 docker 跑 Caddy 反代 + 自动签发 Let's Encrypt 证书。

Mix.install([{:toml, "~> 0.7"}])

defmodule Deploy do
  @doc "运行 shell 命令,流式输出,失败则退出"
  def run!(desc, cmd) do
    IO.puts("\n▶ #{desc}")

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        :ok

      {_, code} ->
        IO.puts("\n❌ 命令失败(退出码 #{code})")
        System.halt(1)
    end
  end

  @doc "上传本地文件到目标主机"
  def scp!(src, remote_dst, %{target: :ssh} = ctx) do
    %{ssh: ssh} = ctx
    key_part = if ssh.key && ssh.key != "", do: "-i #{ssh.key} ", else: ""
    port_part = "-P #{ssh.port} "

    run!(
      "[上传] #{Path.basename(src)} → #{ssh.user}@#{ssh.host}:#{remote_dst}",
      "scp #{port_part}#{key_part}#{src} #{ssh.user}@#{ssh.host}:#{remote_dst}"
    )
  end

  def scp!(src, remote_dst, %{target: :gcloud} = ctx) do
    %{gcloud: %{instance: inst, zone: zone, project: proj}} = ctx

    run!(
      "[上传] #{Path.basename(src)} → VM:#{remote_dst}",
      "gcloud compute scp #{src} #{inst}:#{remote_dst} --zone=#{zone} --project=#{proj}"
    )
  end

  @doc "把 bash 脚本写成临时文件 SCP 过去再执行,避免转义问题"
  def ssh!(desc, script, ctx) do
    tmp_local = Path.join(System.tmp_dir!(), "lan_share-deploy-#{System.unique_integer([:positive])}.sh")
    tmp_remote = "/tmp/lan_share-deploy-remote.sh"
    File.write!(tmp_local, script)
    scp!(tmp_local, tmp_remote, ctx)
    File.rm!(tmp_local)

    case ctx.target do
      :ssh ->
        %{ssh: ssh} = ctx
        key_part = if ssh.key && ssh.key != "", do: "-i #{ssh.key} ", else: ""
        port_part = "-p #{ssh.port} "

        run!(
          desc,
          "ssh #{port_part}#{key_part}#{ssh.user}@#{ssh.host} " <>
            "\"bash #{tmp_remote}; CODE=\\$?; rm -f #{tmp_remote}; exit \\$CODE\""
        )

      :gcloud ->
        %{gcloud: %{instance: inst, zone: zone, project: proj}} = ctx

        run!(
          desc,
          "gcloud compute ssh #{inst} --zone=#{zone} --project=#{proj}" <>
            " --command='bash #{tmp_remote}; CODE=$?; rm -f #{tmp_remote}; exit $CODE'"
        )
    end
  end
end

# ── 参数解析 ─────────────────────────────────────────────────────────────────
args = System.argv()
rollback = "--rollback" in args

config_idx = Enum.find_index(args, &(&1 == "--config"))

toml_path =
  if config_idx do
    args |> Enum.at(config_idx + 1) |> Path.expand()
  else
    Path.join(__DIR__, "deploy.toml")
  end

# ── 加载配置 ──────────────────────────────────────────────────────────────────
root = __DIR__ |> Path.join("..") |> Path.expand()

unless File.exists?(toml_path) do
  IO.puts("❌ 找不到配置文件:#{toml_path}")
  System.halt(1)
end

cfg = toml_path |> File.read!() |> Toml.decode!()

target = (cfg["deploy"] || %{})["target"] || "ssh"

ctx =
  case target do
    "ssh" ->
      ssh = cfg["ssh"] || %{}

      %{
        target: :ssh,
        ssh: %{
          host: ssh["host"],
          port: ssh["port"] || 22,
          user: ssh["user"] || "root",
          key: ssh["key"] || ""
        }
      }

    "gcloud" ->
      g = cfg["gcloud"] || %{}

      %{
        target: :gcloud,
        gcloud: %{
          project: g["project"],
          zone: g["zone"],
          instance: g["instance"]
        }
      }

    other ->
      IO.puts("❌ 不支持的 deploy.target:#{inspect(other)}(只支持 \"ssh\" / \"gcloud\")")
      System.halt(1)
  end

app = cfg["app"] || %{}
svc = cfg["systemd"] || %{}
caddy = cfg["caddy"] || %{}

app_name = app["name"] || "lan_share"
release_name = app["release"] || app_name
deploy_dir = app["deploy_dir"] || "/opt/#{app_name}"
env_local = Path.join(root, app["env_file"] || ".env.prod")
service_name = svc["service"] || "#{app_name}.service"

env_local_exists? = File.exists?(env_local)

caddy_enabled? = Map.get(caddy, "enabled", false) == true

IO.puts("""
🚀 LanShare 部署
   target:     #{target}
   app:        #{app_name}
   deploy_dir: #{deploy_dir}
   service:    #{service_name}
   caddy:      #{if caddy_enabled?, do: "enabled (#{caddy["domain"]})", else: "disabled"}
   env file:   #{if env_local_exists?, do: env_local, else: "(无,使用默认环境变量)"}
   rollback:   #{rollback}
""")

# ── 回滚分支 ─────────────────────────────────────────────────────────────────
if rollback do
  confirm =
    IO.gets("继续回滚?输入 yes 确认:")
    |> to_string()
    |> String.trim()

  unless confirm == "yes" do
    IO.puts("已取消回滚。")
    System.halt(1)
  end

  rollback_script = """
  #!/usr/bin/env bash
  set -euo pipefail

  DEPLOY_DIR="#{deploy_dir}"
  SERVICE_NAME="#{service_name}"
  PREVIOUS_DIR="${DEPLOY_DIR}/previous"

  if [ ! -d "${PREVIOUS_DIR}/bin" ] || [ ! -d "${PREVIOUS_DIR}/lib" ] || [ ! -d "${PREVIOUS_DIR}/releases" ]; then
    echo "❌ ${PREVIOUS_DIR} 不存在或不完整,无法回滚(仅保留 1 个历史版本)"
    exit 1
  fi

  echo "▶ 停止服务..."
  if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    sudo systemctl stop "${SERVICE_NAME}"
    sleep 2
  fi

  echo "▶ 交换 current ↔ previous..."
  ASIDE_DIR="${DEPLOY_DIR}/.rollback-aside"
  sudo rm -rf "${ASIDE_DIR}"
  sudo mkdir -p "${ASIDE_DIR}"

  for item in bin lib releases; do
    if [ -e "${DEPLOY_DIR}/${item}" ]; then
      sudo mv "${DEPLOY_DIR}/${item}" "${ASIDE_DIR}/${item}"
    fi
  done
  for ertsdir in "${DEPLOY_DIR}"/erts-*; do
    [ -e "${ertsdir}" ] && sudo mv "${ertsdir}" "${ASIDE_DIR}/"
  done

  for item in bin lib releases; do
    if [ -e "${PREVIOUS_DIR}/${item}" ]; then
      sudo mv "${PREVIOUS_DIR}/${item}" "${DEPLOY_DIR}/${item}"
    fi
  done
  for ertsdir in "${PREVIOUS_DIR}"/erts-*; do
    [ -e "${ertsdir}" ] && sudo mv "${ertsdir}" "${DEPLOY_DIR}/"
  done

  sudo rm -rf "${ASIDE_DIR}" "${PREVIOUS_DIR}"

  echo "▶ 启动服务..."
  sudo systemctl start "${SERVICE_NAME}"

  echo ""
  echo "✅ 回滚完成"
  echo "  状态: sudo systemctl status ${SERVICE_NAME}"
  echo "  日志: sudo journalctl -u ${SERVICE_NAME} -f"
  """

  Deploy.ssh!("[远端] 回滚中...", rollback_script, ctx)
  IO.puts("\n🎉 回滚流程结束")
  System.halt(0)
end

# ── 本地构建 ─────────────────────────────────────────────────────────────────
File.cd!(root)

Deploy.run!("[本地] 清理旧 release", "rm -rf _build/prod/rel")
Deploy.run!("[本地] 获取依赖", "MIX_ENV=prod mix deps.get --only prod")
Deploy.run!("[本地] 编译", "MIX_ENV=prod mix compile")
Deploy.run!("[本地] 构建 release", "MIX_ENV=prod mix release --overwrite")

# ── 打包 ─────────────────────────────────────────────────────────────────────
release_dir = Path.join([root, "_build", "prod", "rel", release_name])
tarball = Path.join(System.tmp_dir!(), "#{release_name}-release.tar.gz")

Deploy.run!("[本地] 打包", "tar -czf #{tarball} -C #{release_dir} .")

# ── 上传 ─────────────────────────────────────────────────────────────────────
Deploy.scp!(tarball, "/tmp/#{release_name}-release.tar.gz", ctx)

if env_local_exists? do
  Deploy.scp!(env_local, "/tmp/#{app_name}.env", ctx)
end

# ── 远端部署脚本 ─────────────────────────────────────────────────────────────
caddy_block =
  if caddy_enabled? do
    """

    # ── Caddy 反向代理 + 自动 TLS(原生 apt 安装)─────────────────────────
    echo "  配置 Caddy 反代..."

    # 1. 安装 Caddy(仅在未安装时执行)
    if ! command -v caddy >/dev/null 2>&1; then
      echo "  Caddy 未安装,从官方源安装..."
      sudo apt-get update -y
      sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
      curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \\
        | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
      curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \\
        | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
      sudo apt-get update -y
      sudo apt-get install -y caddy
    else
      echo "  Caddy 已安装"
    fi

    # 2. 写 Caddyfile
    sudo tee /etc/caddy/Caddyfile > /dev/null <<CADDYEOF
    {
      #{if caddy["email"] && caddy["email"] != "", do: "email #{caddy["email"]}", else: ""}
    }

    #{caddy["domain"]} {
      encode gzip
      # reverse_proxy 自动处理 WebSocket Upgrade
      reverse_proxy 127.0.0.1:#{caddy["upstream_port"] || 10086}
    }
    CADDYEOF

    # 3. 校验配置并 reload
    sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    sudo systemctl enable caddy
    if systemctl is-active --quiet caddy; then
      sudo systemctl reload caddy
    else
      sudo systemctl restart caddy
    fi

    echo "  Caddy 已就绪"
    """
  else
    "\n# (Caddy 未启用)\n"
  end

env_setup =
  if env_local_exists? do
    """
    mv "/tmp/#{app_name}.env" "${ENV_FILE}"
    """
  else
    """
    # 没有提供本地 .env.prod,使用默认配置
    if [ ! -f "${ENV_FILE}" ]; then
      cat > "${ENV_FILE}" <<'ENVEOF'
    PORT=10086
    ENVEOF
    fi
    """
  end

remote_script = """
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="#{app_name}"
RELEASE_NAME="#{release_name}"
DEPLOY_DIR="#{deploy_dir}"
SERVICE_NAME="#{service_name}"
ENV_FILE="${DEPLOY_DIR}/.env"
TARBALL="/tmp/${RELEASE_NAME}-release.tar.gz"

# ── 目录 & 环境变量 ──────────────────────────────────────────────────────────
sudo mkdir -p "${DEPLOY_DIR}"
sudo chown "$(whoami):$(whoami)" "${DEPLOY_DIR}"
mkdir -p "${DEPLOY_DIR}/var" "${DEPLOY_DIR}/var/uploads"

#{env_setup}

# ── 停止现有服务 ─────────────────────────────────────────────────────────────
if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
  echo "  停止现有服务..."
  sudo systemctl stop "${SERVICE_NAME}"
  sleep 2
fi

# ── 把当前 release 移到 previous/(只保留 1 个历史版本)─────────────────────
echo "  归档当前 release → previous/..."
PREVIOUS_DIR="${DEPLOY_DIR}/previous"
sudo rm -rf "${PREVIOUS_DIR}"
sudo mkdir -p "${PREVIOUS_DIR}"
for item in bin lib releases; do
  if [ -e "${DEPLOY_DIR}/${item}" ]; then
    sudo mv "${DEPLOY_DIR}/${item}" "${PREVIOUS_DIR}/${item}"
  fi
done
for ertsdir in "${DEPLOY_DIR}"/erts-*; do
  [ -e "${ertsdir}" ] && sudo mv "${ertsdir}" "${PREVIOUS_DIR}/"
done

# ── 解压新版本 ───────────────────────────────────────────────────────────────
# var/ 不在 release 里,不会被覆盖,SQLite + uploads 自然保留。
echo "  解压新 release..."
tar -xzf "${TARBALL}" -C "${DEPLOY_DIR}"
rm -f "${TARBALL}"

# ── systemd 服务 ─────────────────────────────────────────────────────────────
echo "  配置 systemd..."
sudo tee "/etc/systemd/system/${SERVICE_NAME}" > /dev/null <<SVCEOF
[Unit]
Description=LanShare LAN file & message share
After=network.target

[Service]
Type=exec
User=$(whoami)
Group=$(whoami)
WorkingDirectory=${DEPLOY_DIR}
EnvironmentFile=-${ENV_FILE}
Environment=LANG=en_US.UTF-8
Environment=LAN_SHARE_DB=${DEPLOY_DIR}/var/lan_share.sqlite3
Environment=LAN_SHARE_UPLOAD_ROOT=${DEPLOY_DIR}/var/uploads
ExecStart=${DEPLOY_DIR}/bin/${RELEASE_NAME} start
ExecStop=${DEPLOY_DIR}/bin/${RELEASE_NAME} stop
Restart=on-failure
RestartSec=5
SyslogIdentifier=${APP_NAME}

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl start "${SERVICE_NAME}"
#{caddy_block}
echo ""
echo "✅ 部署完成"
echo "  状态: sudo systemctl status ${SERVICE_NAME}"
echo "  日志: sudo journalctl -u ${SERVICE_NAME} -f"
echo "  数据: ${DEPLOY_DIR}/var/  (SQLite + uploads,跨部署保留)"
"""

Deploy.ssh!("[远端] 部署中...", remote_script, ctx)

IO.puts("\n🎉 部署流程结束")

if caddy_enabled? && caddy["domain"] do
  IO.puts("""

  🌐 公网访问:https://#{caddy["domain"]}
     (Caddy 首次签发证书需要 DNS 已指向该 VM,且 80/443 已开放)
  """)
end
