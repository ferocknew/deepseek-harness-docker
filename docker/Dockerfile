# syntax=docker/dockerfile:1

# ============ build stage ============
FROM node:24-slim AS build

ARG PNPM_VERSION=11.7.0
# 容器内无 .git 元数据，build 脚本通过该变量获取提交哈希（上游 client-build-environment.ts）
ARG DSH_CLIENT_COMMIT_HASH=0000000
ENV NODE_OPTIONS=--max-old-space-size=4096
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV DSH_CLIENT_COMMIT_HASH=${DSH_CLIENT_COMMIT_HASH}

WORKDIR /src
COPY origin/deepseek-harness/ .

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/* \
 && corepack enable \
 && corepack prepare pnpm@${PNPM_VERSION} --activate \
 && pnpm install --frozen-lockfile --config.dangerouslyAllowAllBuilds=true \
 && pnpm run build \
 && ln -sf /src/apps/cli/lib/bin.js /src/node_modules/.bin/dsh

# ============ runtime stage ============
FROM debian:13-slim

# --- versions ---
ARG NODE_VERSION=24.19.0
ARG PYTHON_VERSION=3.14
ARG UV_INSTALL_DIR=/opt/uv
ARG NVM_DIR=/usr/local/nvm

ENV NODE_VERSION=${NODE_VERSION} \
    PYTHON_VERSION=${PYTHON_VERSION} \
    UV_INSTALL_DIR=${UV_INSTALL_DIR} \
    NVM_DIR=${NVM_DIR} \
    DSH_HOME=/data/dsh \
    DSH_TELEMETRY_DISABLED=1 \
    DSH_WEB_PORT=3080 \
    PATH=${UV_INSTALL_DIR}:${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:/usr/local/bin:/usr/bin:/bin

# --- base tools (清单驱动, 见 docker/debian_tools_list) ---
COPY docker/debian_tools_list /tmp/debian_tools_list
RUN apt-get update \
 && grep -vE '^\s*(#|$)' /tmp/debian_tools_list | xargs apt-get install -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /tmp/debian_tools_list

# --- nvm + node 24 ---
RUN mkdir -p ${NVM_DIR} \
 && curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
 && . ${NVM_DIR}/nvm.sh \
 && nvm install ${NODE_VERSION} \
 && nvm alias default ${NODE_VERSION} \
 && nvm use default

# --- uv + python 3.14 ---
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=${UV_INSTALL_DIR} sh \
 && ${UV_INSTALL_DIR}/uv python install ${PYTHON_VERSION} \
 && PY_BIN="$(${UV_INSTALL_DIR}/uv python find ${PYTHON_VERSION})" \
 && ln -sf "${PY_BIN}" /usr/local/bin/python3 \
 && ln -sf "${PY_BIN}" /usr/local/bin/python \
 && ${UV_INSTALL_DIR}/uv --version && python3 --version

# --- caddy ---
ARG CADDY_VERSION=2.9.1
RUN curl -fsSL -o /tmp/caddy.tar.gz \
      "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
 && tar -xzf /tmp/caddy.tar.gz -C /tmp caddy \
 && mv /tmp/caddy /usr/bin/caddy \
 && rm -f /tmp/caddy.tar.gz \
 && caddy version

# --- app ---
WORKDIR /src
COPY --from=build /src /src
ENV PATH=/src/node_modules/.bin:${PATH}

WORKDIR /workspace
COPY docker/Caddyfile.tmpl /etc/caddy/Caddyfile
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && mkdir -p /data/dsh /workspace

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS --max-time 3 http://127.0.0.1:${DSH_WEB_PORT}/ >/dev/null || exit 1

STOPSIGNAL SIGTERM
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]