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

# Define ARG for build-time placeholders
ARG NEXT_PUBLIC_API_URL_PLACEHOLDER=__NEXT_PUBLIC_API_URL_PLACEHOLDER__
ARG NEXT_PUBLIC_USER_ID_PLACEHOLDER=__NEXT_PUBLIC_USER_ID_PLACEHOLDER__

# Set placeholders as environment variables during build
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL_PLACEHOLDER
ENV NEXT_PUBLIC_USER_ID=$NEXT_PUBLIC_USER_ID_PLACEHOLDER

# Copy dependencies and source code
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/pnpm-lock.yaml ./pnpm-lock.yaml
COPY . .

# Use dev config for build
RUN cp next.config.dev.mjs next.config.mjs && \
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

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

ENTRYPOINT ["/home/nextjs/entrypoint.sh"]
CMD ["node", "server.js"]

