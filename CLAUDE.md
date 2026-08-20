# CLAUDE.md

## 项目

DeepSeek Harness (dsh) 的 Docker 镜像工程。上游源码以 git submodule 引入（`origin/deepseek-harness`），通过 GitHub Actions 构建镜像并推送 GHCR。

## 版本

- 镜像版本号与 `origin/deepseek-harness/package.json` 的 `version` 字段对齐，workflow 自动读取。
- 根目录 `VERSION` 文件同步记录，不带 `v` 前缀。
- 发版：推送 `release-<version>` tag 触发构建。

## 架构决策（本会话解决的问题）

1. `dsh web` 上游硬性禁止 `--host 0.0.0.0`（防止远程代码执行暴露到网络），只能绑定 `127.0.0.1`，因此容器内由 Caddy 反向代理对外暴露。
2. 浏览器访问的 host 必须通过 dsh `--trusted-host` 放行 API 请求：`HTTPS_ACCESS_HOST` 环境变量传入，支持逗号分隔多值。
3. Caddy basic auth 的 bcrypt hash 含 `$` 字符：entrypoint 用 `caddy hash-password` 生成后经 `DSH_AUTH_HASH` 环境变量注入 Caddyfile 的 `{env.}` 模板，避免 Caddyfile 解析转义问题。
4. 镜像分两阶段：构建用 `node:24-slim` + pnpm 11.7.0；运行时用 `debian:13-slim` + nvm（Node 24.19.0）+ uv（Python 3.14）+ caddy + tini。
5. pnpm 11 默认阻止依赖 postinstall 脚本，`pnpm install` 需加 `--config.dangerouslyAllowAllBuilds=true`；构建时设 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` 避免下载浏览器。
6. docker 相关配置全部收敛在 `docker/` 目录（Dockerfile / entrypoint.sh / Caddyfile.tmpl / compose.yaml），workflow 用 `file: docker/Dockerfile`。

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `DSH_HOME` | `/data/dsh` | dsh 数据目录 |
| `DSH_TELEMETRY_DISABLED` | `1` | 关闭遥测 |
| `HTTPS_ACCESS_HOST` | 无 | 对外访问 host，传 dsh `--trusted-host` |
| `DSH_AUTH_USERNAME` | 无 | Caddy basic auth 用户名 |
| `DSH_AUTH_PASSWORD` | 无 | Caddy basic auth 密码 |
| `DSH_WEB_PORT` | `3080` | dsh web 内部端口 |

## 卷

`./data:/data/dsh`、`./workspace:/workspace`（相对 `docker/` 目录）。

## 约束

- 文档（README / CLAUDE.md）不得包含真实内网 IP、密码、域名，一律脱敏。
- 版本号不带 `v` 前缀。
- 本文件与 README 均不超过 200 行，单行不超过 200 字符。