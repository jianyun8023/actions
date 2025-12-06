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

# Builder stage - Clone and build
FROM base AS builder

# Install build dependencies and git
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone official OpenMemory source
RUN git clone --depth 1 https://github.com/mem0ai/mem0.git /tmp/mem0 && \
    cp -r /tmp/mem0/openmemory/api/* /usr/src/openmemory/ && \
    rm -rf /tmp/mem0

# Copy fixed database.py (PostgreSQL support)
COPY database_fixed.py /usr/src/openmemory/app/database.py

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

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

