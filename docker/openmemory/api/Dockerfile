# OpenMemory API - Multi-arch Dockerfile
# Based on: https://github.com/osen77/OpenMemory-MCP
# Supports: linux/amd64, linux/arm64

FROM python:3.12-slim AS base

# Metadata
LABEL maintainer="jianyun8023" \
      org.opencontainers.image.title="OpenMemory API" \
      org.opencontainers.image.description="OpenMemory API - Personal memory layer for LLMs" \
      org.opencontainers.image.source="https://github.com/jianyun8023/actions" \
      org.opencontainers.image.vendor="jianyun8023"

WORKDIR /usr/src/openmemory

# Builder stage - Install dependencies
FROM base AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM base AS runtime

# Create non-root user
RUN useradd -m -u 1001 -s /bin/bash openmemory

# Copy installed packages from builder
COPY --from=builder /root/.local /home/openmemory/.local

# Set PATH for user-installed packages
ENV PATH=/home/openmemory/.local/bin:$PATH

# Copy application code
COPY --chown=openmemory:openmemory config.json default_config.json ./
COPY --chown=openmemory:openmemory . .

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

