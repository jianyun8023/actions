# SSL VPN Client Docker 镜像
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# 说明：当前 SSLVPN 客户端（secgateaccess）安装包仅提供 amd64
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    if [ "${arch}" != "amd64" ]; then \
      echo "ERROR: docker/sslvpnclient 仅支持 linux/amd64（当前架构: ${arch}）。" >&2; \
      exit 1; \
    fi

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    net-tools \
    iproute2 \
    iptables \
    curl \
    ca-certificates \
    dante-server \
    busybox \
    procps \
    expect \
    bash \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 Web 终端（ttyd，下载预编译二进制）
# 资源命名：ttyd.x86_64 / ttyd.aarch64
RUN set -eux; \
    ttyd_arch="x86_64"; \
    curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${ttyd_arch}"; \
    chmod +x /usr/local/bin/ttyd; \
    /usr/local/bin/ttyd -v

# 安装 SSL VPN 客户端
COPY deb/Ubuntu_SSLVPNClient_Setup.deb /tmp/sslvpnclient.deb
RUN apt-get update && \
    apt-get install -y /tmp/sslvpnclient.deb --no-install-recommends && \
    rm /tmp/sslvpnclient.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 复制配置文件
COPY danted.conf.sample /etc/danted.conf.sample
COPY start.sh /opt/start.sh
COPY webui.sh /opt/webui.sh

RUN chmod +x /opt/start.sh /opt/webui.sh

WORKDIR /opt/sslvpnclient

# 数据卷 - 配置持久化
VOLUME ["/opt/sslvpnclient/conf"]

# 暴露端口: 1080=SOCKS5, 8080=Web 终端
EXPOSE 1080 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:8080/ >/dev/null || exit 1

CMD ["/opt/start.sh"]
