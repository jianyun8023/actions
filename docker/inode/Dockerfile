# 基础镜像选择
FROM debian:12-slim

# 镜像元数据
LABEL maintainer="jianyun8023" \
      version="1.0" \
      description="iNode VPN Client with KasmVNC"

# Use the TARGETARCH build argument to get the architecture
ARG TARGETARCH
ARG KASMVNC_VERSION=1.4.0

# 设置非交互模式，避免安装交互提示
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV ARCH=${TARGETARCH}

# KasmVNC 环境变量
ENV VNC_USER=vncuser
ENV VNC_PASSWORD=password
ENV VNC_PROTOCOL=http

# 更新并安装基础依赖
RUN apt-get update && apt-get install -y \
    fluxbox \
    xterm \
    x11-utils \
    net-tools \
    iproute2 \
    iptables \
    wget \
    curl \
    ca-certificates \
    procps \
    libgtk2.0-0 libgdk-pixbuf-2.0-0 libjpeg62-turbo \
    libglib2.0-dev \
    xclip \
    xsel \
    libnm0 \
    dante-server busybox \
    ssl-cert \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 KasmVNC (自动检测架构)
RUN ARCH=$(dpkg --print-architecture) && \
    echo "Detected architecture: $ARCH" && \
    wget https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_bookworm_${KASMVNC_VERSION}_${ARCH}.deb -O /tmp/kasmvnc.deb \
    && apt-get update \
    && dpkg -i /tmp/kasmvnc.deb || apt-get install -y -f \
    && rm -f /tmp/kasmvnc.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 deb 应用
COPY ./deb/inode.${TARGETARCH}_E0626.deb /tmp/inode.deb
RUN apt-get update && apt-get install -y /tmp/inode.deb && rm /tmp/inode.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建必要的目录
RUN mkdir -p /var/lock/subsys

# 复制配置文件
COPY danted.conf.sample /etc/danted.conf.sample
COPY start.sh /opt/start.sh
COPY xstartup /root/.vnc/xstartup

# 设置工作目录
WORKDIR /opt

# 配置权限
RUN chmod +x /opt/start.sh && chmod +x /root/.vnc/xstartup

# 暴露端口（5900 用于 KasmVNC WebSocket，1080 用于 SOCKS5 代理）
EXPOSE 5900 1080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5900/ || exit 1

# 启动脚本
CMD ["/opt/start.sh"]
