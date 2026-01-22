#!/bin/bash
set -e

echo "=== SSL VPN Client Container Starting ==="

# 默认启动后自动 quickconnect（VPN 建链后才会创建 tun0，SOCKS5 才能起来）
# 可通过 AUTO_QUICKCONNECT=0 禁用（例如只想手动在 Web 管理页面里操作）
AUTO_QUICKCONNECT="${AUTO_QUICKCONNECT:-1}"
QUICKCONNECT_RETRY_INTERVAL="${QUICKCONNECT_RETRY_INTERVAL:-10}"

# 尽早尝试建立 VPN 连接（后台重试）
if [ "${AUTO_QUICKCONNECT}" != "0" ]; then
    (
        cd /opt/sslvpnclient 2>/dev/null || true

        # 兼容不同安装路径：优先从 PATH 查找，其次尝试常见路径
        VPN_CMD="${VPN_CMD:-}"
        if [ -z "${VPN_CMD}" ]; then
            VPN_CMD="$(command -v secgateaccess 2>/dev/null || true)"
        fi
        if [ -z "${VPN_CMD}" ]; then
            for p in \
                "/opt/sslvpnclient/secgateaccess" \
                "/opt/SSLVPNClient/secgateaccess" \
                "/usr/local/sslvpnclient/secgateaccess" \
                "/usr/local/bin/secgateaccess" \
                "/usr/bin/secgateaccess" \
                "/usr/sbin/secgateaccess"; do
                if [ -x "${p}" ]; then
                    VPN_CMD="${p}"
                    break
                fi
            done
        fi

        echo "[$(date)] Auto quickconnect enabled (retry interval: ${QUICKCONNECT_RETRY_INTERVAL}s)"
        while true; do
            # 已连接则退出循环（避免刷日志）
            if [ -n "${VPN_CMD}" ] && [ -x "${VPN_CMD}" ] && "${VPN_CMD}" showinfo 2>/dev/null | grep -q "Login User:"; then
                echo "[$(date)] VPN already connected"
                exit 0
            fi

            if [ -z "${VPN_CMD}" ] || [ ! -x "${VPN_CMD}" ]; then
                echo "[$(date)] secgateaccess not found (VPN_CMD='${VPN_CMD:-}')"
            else
                echo "[$(date)] Running: ${VPN_CMD} quickconnect"
                "${VPN_CMD}" quickconnect 2>&1 || true
            fi

            sleep "${QUICKCONNECT_RETRY_INTERVAL}"
        done
    ) &
else
    echo "[$(date)] Auto quickconnect disabled (AUTO_QUICKCONNECT=0)"
fi

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

# 创建 lighttpd 日志目录
mkdir -p /var/log/lighttpd
chown www-data:www-data /var/log/lighttpd

# 启动 Web 管理页面
echo "[$(date)] Starting Web Management UI on port 8080..."
lighttpd -f /etc/lighttpd/lighttpd.conf

echo "[$(date)] Container ready. Use Web Management UI at http://localhost:8080"
echo "[$(date)] SOCKS5 proxy will be available at port 1080 after VPN connection"

# 保持容器运行
tail -f /dev/null
