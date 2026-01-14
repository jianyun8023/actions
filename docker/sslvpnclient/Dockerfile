# SSL VPN Client Docker 镜像
FROM debian:12-slim

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    net-tools \
    iproute2 \
    iptables \
    curl \
    dante-server \
    busybox \
    procps \
    jq \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 SSL VPN 客户端
COPY deb/Ubuntu_SSLVPNClient_Setup.deb /tmp/sslvpnclient.deb
RUN dpkg -i /tmp/sslvpnclient.deb || apt-get install -f -y && \
    rm /tmp/sslvpnclient.deb

# 复制配置文件
COPY danted.conf.sample /etc/danted.conf.sample
COPY start.sh /opt/start.sh
COPY webui.sh /opt/webui.sh

RUN chmod +x /opt/start.sh /opt/webui.sh

WORKDIR /opt/sslvpnclient

# 数据卷 - 配置持久化
VOLUME ["/opt/sslvpnclient/conf"]

# 暴露端口: 1080=SOCKS5, 8080=Web管理界面
EXPOSE 1080 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/api/status || exit 1

CMD ["/opt/start.sh"]
