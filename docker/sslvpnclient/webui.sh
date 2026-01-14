#!/bin/bash
set -euo pipefail

# 极简 Web 终端（浏览器里直接执行命令）
# 基于 ttyd: https://github.com/tsl0922/ttyd
#
# 环境变量：
# - WEB_TERMINAL_PORT: 监听端口（默认 8080）
# - WEB_TERMINAL_CREDENTIALS: BasicAuth 用户名密码（格式 user:pass，可选）
# - WEB_TERMINAL_CWD: 进入终端后的工作目录（默认 /opt/sslvpnclient）
# - WEB_TERMINAL_COMMAND: 启动的命令（默认 /bin/bash）

PORT="${WEB_TERMINAL_PORT:-8080}"
CWD="${WEB_TERMINAL_CWD:-/opt/sslvpnclient}"
COMMAND="${WEB_TERMINAL_COMMAND:-/bin/bash}"

ARGS=(
  --port "${PORT}"
  --writable
  --cwd "${CWD}"
)

if [ -n "${WEB_TERMINAL_CREDENTIALS:-}" ]; then
  ARGS+=( --credential "${WEB_TERMINAL_CREDENTIALS}" )
fi

echo "[$(date)] Starting Web Terminal (ttyd) on port ${PORT}..."
exec ttyd "${ARGS[@]}" "${COMMAND}"
