# deepseek-harness-docker

DeepSeek Harness (`dsh`) 的 Docker 镜像工程。源码以 git submodule 形式引入（`origin/deepseek-harness`），通过 GitHub Actions 构建镜像并发布到 GitHub Packages（GHCR）。

## 版本

镜像版本号与子模块 `origin/deepseek-harness/package.json` 的 `version` 字段对齐（当前 `0.1.0-rc.8`，不带 `v` 前缀）。workflow 构建时自动读取该字段生成镜像 tag，根目录 `VERSION` 文件同步记录。

## 镜像结构

| 组件 | 说明 |
|---|---|
| 运行时底包 | `debian:13-slim` |
| Node.js | 24（通过 nvm 安装，`NODE_VERSION=24.19.0`） |
| Python | 3.14（通过 uv 安装） |
| 反向代理 | Caddy，对外提供 HTTP 服务并做 basic auth |
| 进程管理 | tini（PID 1），信号转发正常 |

`dsh web` 受上游安全限制只能监听 `127.0.0.1`（`--host 0.0.0.0` 被硬性禁止，防止远程代码执行暴露到网络），因此由 Caddy 反向代理到 `127.0.0.1:3080` 对外暴露。

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `DSH_HOME` | `/data/dsh` | dsh 数据目录（会话、凭据等持久化数据） |
| `DSH_TELEMETRY_DISABLED` | `1` | 关闭遥测上报 |
| `HTTPS_ACCESS_HOST` | 无 | 对外访问的 host（如 `10.0.0.10`，替换为你自己的局域网 IP），传入 dsh 的 `--trusted-host` 使浏览器访问该 host 时 API 请求放行；支持逗号分隔多个 |
| `DSH_AUTH_USERNAME` | 无 | Caddy basic auth 用户名（必填） |
| `DSH_AUTH_PASSWORD` | 无 | Caddy basic auth 密码（必填） |
| `DSH_WEB_PORT` | `3080` | dsh web 内部监听端口，一般无需修改 |

## 挂载卷

| 挂载点 | 说明 |
|---|---|
| `./data:/data/dsh` | dsh 持久化数据 |
| `./workspace:/workspace` | agent 工作目录 |

## 快速开始

```bash
# 打任意 tag（版本号由 workflow 自动读取）即可触发构建推送 GHCR
git tag 0.1.0-rc.8
git push origin 0.1.0-rc.8
```

或在仓库 Actions 页面手动触发 `docker-build` workflow。

拉取镜像并启动：

```bash
docker compose -f docker/compose.yaml up -d
```

浏览器访问 `http://<你的局域网IP>`（与 `HTTPS_ACCESS_HOST` 一致），输入 `DSH_AUTH_USERNAME` / `DSH_AUTH_PASSWORD` 登录。

## 开发约束

- 版本号不带 `v` 前缀；发版 tag 格式 `release-<version>`。
- 文档不得包含真实内网 IP、密码、域名，一律脱敏。
- docker 相关配置收敛在 `docker/` 目录。
- 构建期 `pnpm install` 需 `--config.dangerouslyAllowAllBuilds=true`（pnpm 11 默认阻止 postinstall）；设 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` 跳过浏览器下载。

## 目录结构

```text
.
├── .github/workflows/docker-build.yml   # GH Actions：构建并推送 GHCR
├── docker/
│   ├── Dockerfile                       # 多阶段构建（build: node24-slim / runtime: debian13-slim）
│   ├── entrypoint.sh                    # 容器启动脚本（启动 dsh web + caddy）
│   ├── Caddyfile.tmpl                   # Caddy 反代配置模板（{env.} 占位符）
│   └── compose.yaml                     # docker compose 部署示例（卷相对路径 ./data、./workspace）
├── VERSION                              # 当前版本号（与 package.json 对齐）
└── origin/deepseek-harness/             # 上游源码 submodule
```
