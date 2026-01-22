#!/bin/bash
set -x

# ==================== Danted SOCKS5 代理监控 ====================
# 后台运行 danted 监控，等待 tun0 接口启动后自动开启代理
(
  MONITOR_TUN0=1
  while [ $MONITOR_TUN0 -eq 1 ]; do
    if ip link show tun0 >/dev/null 2>&1; then
      if ip -4 addr show tun0 | grep -q 'inet' >/dev/null 2>&1; then
        if ! pgrep danted >/dev/null; then
          echo "tun0 with IPv4 detected, starting danted..."
          # 配置 danted
          cp /etc/danted.conf.sample /run/danted.conf
          externals=""
          for iface in $({ ip -f inet -o addr; ip -f inet6 -o addr; } | sed -E 's/^[0-9]+: ([^ ]+) .*/\1/'); do
            externals="${externals}external: $iface\\n"
          done
          sed s/^#external-lines/"$externals"/ -i /run/danted.conf
          chmod a+w /tmp
          su daemon -s /usr/sbin/danted -- -f /run/danted.conf
          MONITOR_TUN0=0
        fi
      fi
    fi
    sleep 1
  done
) &

# ==================== iptables 配置 ====================
# 使用 iptables-legacy 确保兼容性
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

# NAT 转发
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# 拒绝 tun0 侧主动请求的连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i tun0 -p tcp -j DROP

# ==================== KasmVNC 配置 ====================
VNC_USER_NAME=${VNC_USER:-vncuser}
VNC_USER_PASSWORD=${VNC_PASSWORD:-password}
VNC_USER_PROTOCOL=${VNC_PROTOCOL:-http}

# 清理可能存在的旧锁文件
rm -f /tmp/.X0-lock
rm -f /tmp/.X11-unix/X0

# 创建 KasmVNC 用户
echo "Creating KasmVNC user: $VNC_USER_NAME"
echo -e "$VNC_USER_PASSWORD\n$VNC_USER_PASSWORD\n" | kasmvncpasswd -u $VNC_USER_NAME -w -r

# 写入 KasmVNC 默认配置
mkdir -p $HOME/.vnc
cat > $HOME/.vnc/kasmvnc.yaml << EOF
network:
  protocol: $VNC_USER_PROTOCOL
  websocket_port: 5900
  ssl:
    require_ssl: false
command_line:
  prompt: false
EOF

# 启动 KasmVNC
echo "Starting KasmVNC server..."
kasmvncserver :0 -geometry 1280x720 -depth 24

export DISPLAY=:0

# 启动 fluxbox 窗口管理器
echo "Starting fluxbox..."
fluxbox &
sleep 2  # 等待 fluxbox 启动

# ==================== iNode 客户端启动 ====================
echo "Starting iNodeClient..."
/etc/init.d/iNodeAuthService restart

echo "Architecture: $ARCH"
case "$ARCH" in
  arm64)
    /opt/apps/com.client.inode.arm/files/.iNode/iNodeClient
    ;;
  amd64)
    /opt/apps/com.client.inode.amd/files/.iNode/iNodeClient
    ;;
  *)
    echo "unknown architecture: $ARCH"
    ;;
esac
