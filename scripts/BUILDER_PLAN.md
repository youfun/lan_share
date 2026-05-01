# 方案 B:专用构建机(Dedicated Builder Host)

> 目的:解耦 **构建机** 与 **部署目标**。在外部 builder 上跑 `mix release`,把
> 产物 tarball 投到 deploy target;部署目标不需要装 Erlang/Elixir,只跑 release。
> 思路对标 GitHub Actions 的 self-hosted runner。

## 1. 为什么需要

- `exqlite` 是 NIF,产物绑定构建机的 OS / glibc / CPU 架构,不能用 Windows/macOS 直接编 → Linux 部署
- 不希望生产 VPS 装 Elixir SDK + `_build/` + `deps/`(占空间、暴露源码)
- 一台 builder 可服务多个项目,或多个目标架构(再加 builder 即可水平扩)
- 编译密集型任务隔离到 builder,不跟生产 VPS 抢 CPU

## 2. 配置(toml 增量)

```toml
# scripts/deploy.toml
[build]
mode = "builder"             # "local" | "builder",默认 "local"

# 仅当 mode = "builder" 时读取
[build.builder]
target   = "ssh"             # "ssh" | "gcloud",形状与 [deploy].target 一致
host     = "build.example.com"
port     = 22
user     = "ci"
key      = ""                # 留空使用 ~/.ssh/id_rsa
work_dir = "/var/lib/ci/lan_share"  # builder 上的工作目录,缓存 deps/_build
```

## 3. 整体流程

```diagram
╭─────────────╮          ╭──────────────╮          ╭──────────────╮
│ 本地开发机  │  rsync   │   builder    │   scp    │ deploy target│
│             │  source  │              │ release  │  (生产 VPS)  │
│ deploy.exs  │ ───────▶ │  mix release │ ◀────── │              │
│             │          │              │ tarball  │ systemd 启动 │
╰─────────────╯          ╰──────────────╯          ╰──────────────╯
       ▲                                                  │
       ╰────────── ssh / scp 控制流 ──────────────────────╯
```

阶段拆解:

| # | 主体 | 动作 |
|---|---|---|
| 1 | 本地 | `rsync -az --delete --exclude={_build,deps,.git,var,_build/prod/rel}` 推到 `builder:${work_dir}/src/` |
| 2 | 本地→builder | `ssh builder: cd ${work_dir}/src && MIX_ENV=prod mix deps.get --only prod` |
| 3 | builder | `MIX_ENV=prod mix release --overwrite`(deps/ 和 _build/ 复用,增量) |
| 4 | builder | `tar -czf ${work_dir}/release.tar.gz -C _build/prod/rel/lan_share .` |
| 5 | 本地 | `scp builder:${work_dir}/release.tar.gz → /tmp/lan_share-release.tar.gz` |
| 6 | 本地→deploy target | 走现有 [deploy.exs](deploy.exs) 后半段(scp tarball、停服、归档 previous/、解压、systemd reload) |

**Why route through 本地 而不是 builder→deploy target 直连?**
- builder 不必拥有 deploy target 的凭证(凭证扩散面更小)
- 本地一台机器同时持有两端的 SSH key,运维心智模型简单
- 文件不大(release tarball 通常 < 30 MB),双跳延迟可接受

可选:如果 builder 跟 deploy target 在同一 VPC,而本地是慢网,可以加一个
`[build.builder].direct_to_deploy = true` 让 tarball 直接从 builder scp 到 deploy
target,跳过本地中转。

## 4. Builder 一次性环境

builder 需要预装:

```bash
# Debian / Ubuntu 示例
sudo apt update
sudo apt install -y build-essential git curl rsync

# 推荐用 asdf 锁版本(与项目 .tool-versions 同步)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. ~/.asdf/asdf.sh' >> ~/.bashrc
source ~/.bashrc

asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.2
asdf install elixir 1.18.0-otp-27
asdf global erlang 27.2
asdf global elixir 1.18.0-otp-27

mkdir -p /var/lib/ci/lan_share
sudo chown ci:ci /var/lib/ci
```

工作目录布局(每次构建后的状态):

```
/var/lib/ci/lan_share/
├── src/                    ← 当前构建的源码(rsync 持续覆盖)
│   ├── lib/
│   ├── mix.exs
│   ├── deps/               ← 跨构建缓存(随 src/ 一起被 rsync 但 --exclude 保留)
│   └── _build/prod/        ← 跨构建缓存
└── release.tar.gz          ← 最新构建产物
```

⚠️ 关键:rsync 命令必须 `--exclude=_build --exclude=deps`,**否则本地的空 _build/deps
会覆盖 builder 上的缓存**,每次都全量重编。

## 5. deploy.exs 改造点

新增模块 `Builder`:

```elixir
defmodule Builder do
  def build!(:local, root, release_name, _ctx), do: build_locally(root, release_name)
  def build!(:builder, root, release_name, %{builder: bctx}), do: build_remote(root, release_name, bctx)

  defp build_locally(root, release_name) do
    Deploy.run!("[本地] mix release", "MIX_ENV=prod mix release --overwrite")
    src = Path.join([root, "_build/prod/rel", release_name])
    tarball = Path.join(System.tmp_dir!(), "#{release_name}-release.tar.gz")
    Deploy.run!("[本地] tar", "tar -czf #{tarball} -C #{src} .")
    tarball
  end

  defp build_remote(root, release_name, bctx) do
    Deploy.run!("[本地→builder] rsync source",
      "rsync -az --delete \\
         --exclude=_build --exclude=deps --exclude=.git --exclude=var \\
         #{root}/ #{bctx.user}@#{bctx.host}:#{bctx.work_dir}/src/")

    Deploy.run!("[builder] mix release",
      ssh_cmd(bctx, \"\"\"
        set -euo pipefail
        cd #{bctx.work_dir}/src
        export MIX_ENV=prod
        mix deps.get --only prod
        mix compile
        mix release --overwrite
        tar -czf #{bctx.work_dir}/release.tar.gz -C _build/prod/rel/#{release_name} .
      \"\"\"))

    tarball = Path.join(System.tmp_dir!(), "#{release_name}-release.tar.gz")
    Deploy.run!("[builder→本地] scp tarball",
      "scp #{bctx.user}@#{bctx.host}:#{bctx.work_dir}/release.tar.gz #{tarball}")
    tarball
  end

  defp ssh_cmd(bctx, script) do
    "ssh #{bctx.user}@#{bctx.host} \"#{escape(script)}\""
  end

  defp escape(s), do: String.replace(s, ~s("), ~s(\\"))
end
```

主流程改成:

```elixir
build_mode = (cfg["build"] || %{})["mode"] || "local"
builder_ctx = build_builder_ctx(cfg["build"])  # 仅 mode = "builder" 时构造
tarball = Builder.build!(String.to_atom(build_mode), root, release_name, %{builder: builder_ctx})
# ...其余 scp 上传 + 远端 deploy 不变
```

## 6. Edge cases

| 情况 | 处理 |
|---|---|
| Builder 上 `release.tar.gz` 残留(上次构建失败) | 构建前 `rm -f ${work_dir}/release.tar.gz` |
| 多人/多 worktree 并发部署 | 共用 `work_dir` 会冲突;暂不解决,改 toml 用各自 `work_dir` 区分 |
| Builder 与 deploy target 架构不一致 | 用户配置错误,deploy target 启动时 NIF 报错;在 deploy.exs 里加 `uname -m` 校验 |
| 源码包含未提交改动 | rsync 用工作树,会一起带上;符合"想测什么部署什么"的直觉 |
| Erlang/Elixir 版本漂移 | 强烈建议项目根放 `.tool-versions`,builder 装 asdf 自动切换 |
| Builder 磁盘塞满 | `_build` 30 天清理 cron;或在 deploy.exs 里加 `--clean-builder` 选项 |

## 7. 与方案 A / C 对比

| | 方案 A:VPS 自构建 | **方案 B:专用 builder** | 方案 C:本地 Docker 跨编 |
|---|---|---|---|
| 额外机器 | 不需要 | 需要一台 | 不需要 |
| VPS 装 Elixir? | 是 | **否** | 否 |
| 跨架构灵活性 | 与 VPS 绑死 | **挂多 builder 即可** | 容器镜像选什么编什么 |
| 首次部署速度 | 慢(VPS 性能) | **快(builder 性能)** | 慢(本地容器拉镜像) |
| 增量构建 | 是 | **是** | 是 |
| 凭证面 | 本地→VPS | 本地→builder + builder→? | 本地 |
| 适用 | 一次性玩具 | **多项目 / 多架构 / 注重生产洁净** | 单人多目标 |

## 8. 后续扩展(不在本次实现)

1. `[build.builder.x86_64]` / `[build.builder.arm64]` 矩阵,部署时按 deploy target arch 自动选 builder
2. `--clean-builder` 命令清理 builder 上的 deps/_build 缓存
3. CI 自动化:把 builder 换成 GitHub Actions self-hosted runner,deploy.exs 改成 dispatch GitHub workflow
4. 构建产物缓存:builder 把 `release.tar.gz` 按 git sha 命名归档(`release-${sha}.tar.gz`),deploy.exs 支持 `--release <sha>` 直接拉历史产物部署/回滚

## 9. 落地清单(下一步实现时按此顺序)

- [ ] [scripts/deploy.toml](deploy.toml) 加 `[build]` + `[build.builder]` 段
- [ ] [scripts/deploy.exs](deploy.exs) 加 `Builder` 模块,主流程切到它
- [ ] 加测试:解析 toml 时 `[build].mode = "builder"` 但缺 `[build.builder].host` 应直接报错(快速失败)
- [ ] 写 `scripts/setup-builder.sh`(builder 一次性环境脚本)
- [ ] [README.md](../README.md) "构建发布包" 章节加一节 "用 builder 远程构建"
