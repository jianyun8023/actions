FROM debian:bookworm-slim

# 镜像元数据
LABEL maintainer="jianyun8023" \
      version="1.0" \
      description="EasyConnect VPN Client with KasmVNC"

ARG TARGETARCH
ARG KASMVNC_VERSION=1.4.0

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# KasmVNC 环境变量
ENV VNC_USER=vncuser
ENV VNC_PASSWORD=password
ENV VNC_PROTOCOL=http

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libgtk2.0-0 libx11-xcb1 libxtst6 libnss3 libasound2 libdbus-glib-1-2 iptables xclip \
        dante-server psmisc x11-utils \
        busybox libssl-dev iproute2 tinyproxy-bin fonts-noto-cjk-extra \
        fluxbox wget ssl-cert curl ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 KasmVNC (bookworm 版本，自动检测架构)
RUN ARCH=$(dpkg --print-architecture) && \
    echo "Detected architecture: $ARCH" && \
    wget https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_bookworm_${KASMVNC_VERSION}_${ARCH}.deb -O /tmp/kasmvnc.deb \
    && apt-get update \
    && dpkg -i /tmp/kasmvnc.deb || apt-get install -y -f \
    && rm -f /tmp/kasmvnc.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG EC_URL

RUN cd tmp &&\
    busybox wget "${EC_URL}" -O EasyConnect.deb &&\
    dpkg -i EasyConnect.deb && rm EasyConnect.deb

COPY ./docker-root /

RUN rm -f /usr/share/sangfor/EasyConnect/resources/conf/easy_connect.json &&\
    mv /usr/share/sangfor/EasyConnect/resources/conf/ /usr/share/sangfor/EasyConnect/resources/conf_backup &&\
    ln -s /root/conf /usr/share/sangfor/EasyConnect/resources/conf

RUN chmod +x /root/.vnc/xstartup

COPY --from=fake-hwaddr fake-hwaddr/fake-hwaddr.so /usr/local/lib/fake-hwaddr.so

#ENV TYPE="" PASSWORD="" LOOP=""
#ENV DISPLAY

VOLUME /root/ /usr/share/sangfor/EasyConnect/resources/logs/

# 暴露端口 (5900 KasmVNC, 1080 SOCKS5, 8888 tinyproxy)
EXPOSE 5900 1080 8888

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5900/ || exit 1

CMD ["start.sh"]
