# 基础镜像选择
FROM debian:12-slim

# 镜像元数据
LABEL version="3.2.38.8" \
      description="TrustAccess VPN Client with Web Management and SOCKS5 Proxy"

# 设置非交互模式，避免安装交互提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新并安装基础依赖
RUN apt-get update && apt-get install -y \
    lighttpd \
    dante-server \
    iproute2 \
    iptables \
    curl \
    wget \
    ca-certificates \
    procps \
    net-tools \
    jq \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 TrustAccess VPN 客户端
COPY deb/trustaccess_3.2.38.8_amd64.deb /tmp/
RUN apt-get update && \
    # 解压 DEB 包但不配置
    dpkg --unpack /tmp/trustaccess_3.2.38.8_amd64.deb && \
    # 移除会失败的 postinst 脚本
    rm -f /var/lib/dpkg/info/trustaccess.postinst && \
    # 创建一个空的 postinst 脚本
    echo "#!/bin/sh" > /var/lib/dpkg/info/trustaccess.postinst && \
    echo "exit 0" >> /var/lib/dpkg/info/trustaccess.postinst && \
    chmod +x /var/lib/dpkg/info/trustaccess.postinst && \
    # 配置包（使用空的 postinst 脚本）
    dpkg --configure trustaccess && \
    # 修复依赖
    apt-get install -f -y && \
    # 验证安装
    ls -la /usr/local/trustaccess/bin/ || echo "Warning: TrustAccess binaries location different" && \
    # 清理
    rm /tmp/trustaccess_3.2.38.8_amd64.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 复制配置文件
COPY danted.conf.sample /etc/danted.conf.sample
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY start.sh /opt/start.sh

# 复制 Web 管理界面
COPY www/ /var/www/html/

# 复制 CGI 脚本
COPY cgi-bin/ /var/www/cgi-bin/

# 设置工作目录
WORKDIR /opt

# 配置权限
RUN chmod +x /opt/start.sh && \
    chmod +x /var/www/cgi-bin/*.cgi && \
    chown -R www-data:www-data /var/www/html && \
    chown -R www-data:www-data /var/www/cgi-bin && \
    mkdir -p /var/log/lighttpd && \
    chown -R www-data:www-data /var/log/lighttpd

# 暴露端口（8080 用于 Web 管理界面，1080 用于 SOCKS5 代理）
EXPOSE 8080 1080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# 启动脚本
CMD ["/opt/start.sh"]
