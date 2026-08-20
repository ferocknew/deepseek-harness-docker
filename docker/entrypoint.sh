#!/usr/bin/env bash
set -euo pipefail

# ---- 运行环境 ----
export DSH_HOME="${DSH_HOME:-/data/dsh}"
export DSH_TELEMETRY_DISABLED="${DSH_TELEMETRY_DISABLED:-1}"
DSH_WEB_PORT="${DSH_WEB_PORT:-3080}"

# nvm 提供的 node
export NVM_DIR="${NVM_DIR:-/usr/local/nvm}"
# shellcheck disable=SC1091
. "${NVM_DIR}/nvm.sh" >/dev/null 2>&1 || true
nvm use default >/dev/null 2>&1 || true

# uv 提供的 python（PATH 已在 Dockerfile 中设置）
mkdir -p "${DSH_HOME}" /workspace

# ---- 必填参数校验 ----
: "${DSH_AUTH_USERNAME:?DSH_AUTH_USERNAME is required}"
: "${DSH_AUTH_PASSWORD:?DSH_AUTH_PASSWORD is required}"
: "${HTTPS_ACCESS_HOST:?HTTPS_ACCESS_HOST is required}"

# ---- 生成 Caddy basic auth 哈希（bcrypt，含 $ 字符，经环境变量传递避免 Caddyfile 转义问题）----
DSH_AUTH_HASH="$(caddy hash-password --plaintext "${DSH_AUTH_PASSWORD}")"
export DSH_AUTH_HASH

# ---- 启动 dsh web（仅允许监听 127.0.0.1，上游安全限制）----
TRUSTED_ARGS=()
IFS=',' read -r -a ACCESS_HOSTS <<< "${HTTPS_ACCESS_HOST}"
for h in "${ACCESS_HOSTS[@]}"; do
  h="$(echo "${h}" | xargs)" # 去除首尾空白
  [ -n "${h}" ] && TRUSTED_ARGS+=(--trusted-host "${h}")
done

echo "[entrypoint] starting dsh web on 127.0.0.1:${DSH_WEB_PORT} (trusted: ${HTTPS_ACCESS_HOST})"
dsh web \
  --host 127.0.0.1 \
  --port "${DSH_WEB_PORT}" \
  --no-open \
  "${TRUSTED_ARGS[@]}" &

# ---- 启动 caddy 反向代理（前台）----
echo "[entrypoint] starting caddy reverse proxy"
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile