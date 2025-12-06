# syntax=docker/dockerfile:1
# OpenMemory UI - Optimized Multi-arch Dockerfile
# 编译一次，多平台复用（amd64/arm64）

# ============================================
# Build stage - 只在构建平台执行一次
# ============================================
FROM --platform=$BUILDPLATFORM node:18-alpine AS builder

# 安装 pnpm
RUN apk add --no-cache libc6-compat && \
    corepack enable && \
    corepack prepare pnpm@latest --activate

WORKDIR /app

# 复制依赖文件（利用缓存）
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# 复制源代码并构建
COPY . .
RUN cp next.config.dev.mjs next.config.mjs && \
    echo "NEXT_PUBLIC_API_URL=NEXT_PUBLIC_API_URL" > .env && \
    echo "NEXT_PUBLIC_USER_ID=NEXT_PUBLIC_USER_ID" >> .env && \
    echo "INTERNAL_API_URL=http://openmemory-api:8765" >> .env && \
    pnpm build

# ============================================
# Runtime stage - 多平台复用构建产物
# ============================================
FROM node:18-alpine AS runner

LABEL maintainer="jianyun8023" \
      org.opencontainers.image.title="OpenMemory UI" \
      org.opencontainers.image.description="OpenMemory Web Interface" \
      org.opencontainers.image.source="https://github.com/jianyun8023/actions"

WORKDIR /app
ENV NODE_ENV=production

# 创建非 root 用户
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# 复制构建产物（纯 JavaScript，跨平台通用）
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# 复制 entrypoint 脚本
COPY --chown=nextjs:nodejs entrypoint.sh /home/nextjs/entrypoint.sh
RUN sed -i 's/\r$//' /home/nextjs/entrypoint.sh && \
    chmod +x /home/nextjs/entrypoint.sh

USER nextjs

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

ENTRYPOINT ["/home/nextjs/entrypoint.sh"]
CMD ["node", "server.js"]
