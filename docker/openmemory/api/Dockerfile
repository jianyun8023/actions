# OpenMemory API - Multi-arch Dockerfile
# Based on: https://github.com/mem0ai/mem0 (官方仓库)
# Supports: linux/amd64, linux/arm64
# Fixed: PostgreSQL support (check_same_thread issue)

FROM python:3.12-slim AS base

# Metadata
LABEL maintainer="jianyun8023" \
      org.opencontainers.image.title="OpenMemory API" \
      org.opencontainers.image.description="OpenMemory API - Personal memory layer for LLMs (PostgreSQL Fixed)" \
      org.opencontainers.image.source="https://github.com/jianyun8023/actions" \
      org.opencontainers.image.vendor="jianyun8023"

WORKDIR /usr/src/openmemory

# Builder stage - Build from local source
FROM base AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy local source code (不复制 config.json，允许用户通过挂载或 API 配置)
COPY requirements.txt /usr/src/openmemory/
COPY main.py /usr/src/openmemory/
COPY default_config.json /usr/src/openmemory/
# config.json 不复制到镜像，用户可通过以下方式配置：
# 1. 挂载 config.json 文件
# 2. 通过 API /api/v1/config 配置
COPY alembic.ini /usr/src/openmemory/
COPY alembic /usr/src/openmemory/alembic
COPY app /usr/src/openmemory/app

# Install Python dependencies
RUN pip install --no-cache-dir --user -r /usr/src/openmemory/requirements.txt

# Runtime stage
FROM base AS runtime

# Create non-root user
RUN useradd -m -u 1001 -s /bin/bash openmemory

# Copy installed packages and application from builder
COPY --from=builder /root/.local /home/openmemory/.local
COPY --from=builder /usr/src/openmemory /usr/src/openmemory

# Set PATH for user-installed packages
ENV PATH=/home/openmemory/.local/bin:$PATH

# Fix ownership
RUN chown -R openmemory:openmemory /usr/src/openmemory

# Create data directories
RUN mkdir -p /var/lib/openmemory && \
    chown -R openmemory:openmemory /var/lib/openmemory

# Switch to non-root user
USER openmemory

# Health check (检查根路径而不是 /docs，更轻量)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8765/').read()" || exit 1

EXPOSE 8765

# Default command (can be overridden in docker-compose)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8765"]

