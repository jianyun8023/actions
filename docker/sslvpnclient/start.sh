#!/bin/bash
set -e

echo "=== SSL VPN Client Container Starting ==="

# 配置 danted SOCKS5 代理
cp /etc/danted.conf.sample /run/danted.conf

# 动态添加网络接口
externals=""
for iface in $({ ip -f inet -o addr; ip -f inet6 -o addr; } | sed -E 's/^[0-9]+: ([^ ]+) .*/\1/'); do
    externals="${externals}external: $iface\\n"
done
sed s/^#external-lines/"$externals"/ -i /run/danted.conf

# 后台监控 tun 设备并启动 danted
(while true; do
    sleep 5
    # 检查 tun0 是否存在且 danted 未在运行
    if [ -d /sys/class/net/tun0 ] && ! pgrep -x danted > /dev/null 2>&1; then
        chmod a+w /tmp
        echo "[$(date)] Starting danted on port 1080..."
        su daemon -s /bin/sh -c "/usr/sbin/danted -f /run/danted.conf"
        sleep 1
        if pgrep -x danted > /dev/null 2>&1; then
            echo "[$(date)] danted started successfully"
        else
            echo "[$(date)] Failed to start danted"
        fi
    fi
done) &

# 使用 iptables-legacy 确保兼容性
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

# 配置 NAT 转发 (当 tun0 存在时)
(while true; do
    sleep 5
    if [ -d /sys/class/net/tun0 ]; then
        iptables -t nat -C POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null || \
            iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
        break
    fi
done) &

# 启动 Web 管理界面
echo "[$(date)] Starting Web UI on port 8080..."
/opt/webui.sh &

echo "[$(date)] Container ready. Use Web UI at http://localhost:8080"
echo "[$(date)] SOCKS5 proxy will be available at port 1080 after VPN connection"

# 保持容器运行
tail -f /dev/null
