# 基础镜像选择
FROM debian:12-slim

# Use the TARGETARCH build argument to get the architecture
ARG TARGETARCH

# 设置非交互模式，避免安装交互提示
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV VNC_PASSWORD=123456

# 更新并安装基础依赖
RUN apt-get update && apt-get install -y \
    x11vnc \
    xvfb \
    supervisor \
    dbus-x11 \
    xfce4 xfce4-goodies \
    net-tools \
    iproute2 \
    iptables \
    wget \
    curl \
    libgtk2.0-0  libgdk-pixbuf-2.0-0 libjpeg62-turbo \
    libglib2.0-dev \
    xclip  \
    xsel \
    libnm0 \
    dante-server busybox \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


# 安装 deb 应用
COPY ./deb /tmp/deb

RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        echo "Running on amd64"; \
        apt install /tmp/deb/inode.amd_E0626.deb && rm /tmp/deb/inode.amd_E0626.deb; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
        echo "Running on arm64"; \
        apt install /tmp/deb/inode.arm_E0626.deb && rm /tmp/deb/inode.arm_E0626.deb; \
    else \
        echo "Running on unknown architecture: ${TARGETARCH}"; \
        exit 1; \
    fi

# 复制启动脚本
COPY danted.conf.sample /etc/danted.conf.sample
COPY start.sh /opt/start.sh
# 设置工作目录
WORKDIR /opt

# 配置 x11vnc 密码
RUN mkdir ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd \
    && chmod +x /opt/start.sh

# 复制 Supervisor 配置文件
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 暴露端口（5900 用于 VNC，1080 用于 VPN）
EXPOSE 5900 1080

# 启动 Supervisor
CMD ["/usr/bin/supervisord"]