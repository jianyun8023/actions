FROM devkitpro/devkita64:latest

# 移除可能无效/需认证的 devkitPro APT 源以避免 403
RUN rm -f /etc/apt/sources.list.d/devkitpro*.list || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       git cmake make zip python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 默认环境变量，可被运行时覆盖
ENV ATMOSPHERE_REPO=https://github.com/Atmosphere-NX/Atmosphere.git \
    ATMOSPHERE_REF=master \
    WORKDIR_PATH=/work \
    OUT_DIR=/out

WORKDIR /usr/local/bin
ADD build-atmosphere.sh /usr/local/bin/build-atmosphere.sh
RUN chmod +x /usr/local/bin/build-atmosphere.sh && mkdir -p /out /work

WORKDIR /work
VOLUME ["/out"]

CMD ["/usr/local/bin/build-atmosphere.sh"]