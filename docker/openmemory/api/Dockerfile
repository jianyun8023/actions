# syntax=docker/dockerfile:1
# OpenMemory API - Multi-arch Dockerfile (Optimized)
# Supports: linux/amd64, linux/arm64
# Fixed: PostgreSQL support (check_same_thread issue)

FROM python:3.12-slim AS base

LABEL maintainer="jianyun8023" \
      org.opencontainers.image.title="OpenMemory API" \
      org.opencontainers.image.description="OpenMemory API - Personal memory layer for LLMs (PostgreSQL Fixed)" \
      org.opencontainers.image.source="https://github.com/jianyun8023/actions" \
      org.opencontainers.image.vendor="jianyun8023"

WORKDIR /usr/src/openmemory

# ============================================
# Builder stage - Install dependencies first
# ============================================
FROM base AS builder

# Install build dependencies with cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ && rm -rf /var/lib/apt/lists/*

# 关键优化：先复制 requirements.txt 并安装依赖
# 这样代码修改时不会重新安装依赖
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user -r requirements.txt

# 再复制源代码（变化频繁，放在依赖安装之后）
COPY main.py default_config.json alembic.ini ./
COPY alembic/ alembic/
COPY app/ app/

# ============================================
# Runtime stage - Minimal production image
# ============================================
FROM base AS runtime

# Create non-root user and directories
RUN useradd -m -u 1001 -s /bin/bash openmemory && \
    mkdir -p /var/lib/openmemory && \
    chown -R openmemory:openmemory /var/lib/openmemory

# Copy installed packages and application
COPY --from=builder /root/.local /home/openmemory/.local
COPY --from=builder --chown=openmemory:openmemory /usr/src/openmemory /usr/src/openmemory

ENV PATH=/home/openmemory/.local/bin:$PATH

USER openmemory

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8765/health').read()" || exit 1

EXPOSE 8765

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8765"]
