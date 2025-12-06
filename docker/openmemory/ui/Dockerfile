# OpenMemory UI - Multi-arch Dockerfile
# Based on: https://github.com/osen77/OpenMemory-MCP
# Supports: linux/amd64, linux/arm64

# syntax=docker.io/docker/dockerfile:1

# Base stage for common setup
FROM node:18-alpine AS base

# Metadata
LABEL maintainer="jianyun8023" \
      org.opencontainers.image.title="OpenMemory UI" \
      org.opencontainers.image.description="OpenMemory Web Interface - Personal memory management" \
      org.opencontainers.image.source="https://github.com/jianyun8023/actions" \
      org.opencontainers.image.vendor="jianyun8023"

# Install dependencies for pnpm
RUN apk add --no-cache libc6-compat curl && \
    corepack enable && \
    corepack prepare pnpm@latest --activate

WORKDIR /app

# Dependencies stage
FROM base AS deps

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Builder stage
FROM base AS builder
WORKDIR /app

# Copy dependencies and source code
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/pnpm-lock.yaml ./pnpm-lock.yaml
COPY . .

# Use dev config and create .env with placeholder values
# 这些占位符会在运行时被 entrypoint.sh 替换为实际环境变量值
RUN cp next.config.dev.mjs next.config.mjs && \
    echo "NEXT_PUBLIC_API_URL=NEXT_PUBLIC_API_URL" > .env && \
    echo "NEXT_PUBLIC_USER_ID=NEXT_PUBLIC_USER_ID" >> .env && \
    pnpm build

# Runtime stage
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy and prepare entrypoint script
COPY --chown=nextjs:nodejs entrypoint.sh /home/nextjs/entrypoint.sh
RUN sed -i 's/\r$//' /home/nextjs/entrypoint.sh && \
    chmod +x /home/nextjs/entrypoint.sh

# Switch to non-root user
USER nextjs

# Health check (使用 Node.js 内置 http 模块，无需额外依赖)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

ENTRYPOINT ["/home/nextjs/entrypoint.sh"]
CMD ["node", "server.js"]

