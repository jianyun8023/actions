#!/bin/bash
set -e

echo "=== TrustAccess VPN Container Starting ==="

# 配置 iptables
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

# 查找 trustaccess-serverd
SERVERD_BIN=""
for p in \
    /usr/local/trustaccess/trustaccess-serverd \
    /usr/local/trustaccess/bin/trustaccess-serverd \
    /usr/bin/trustaccess-serverd \
    /opt/trustaccess/bin/trustaccess-serverd; do
    if [ -x "$p" ]; then
        SERVERD_BIN="$p"
        break
    fi
done

if [ -z "$SERVERD_BIN" ]; then
    echo "ERROR: trustaccess-serverd not found"
    exit 1
fi

echo "Starting TrustAccess serverd: $SERVERD_BIN"
$SERVERD_BIN &
sleep 2

# 配置 danted
cp /etc/danted.conf.sample /run/danted.conf
externals=""
for iface in $({ ip -f inet -o addr; ip -f inet6 -o addr; } | sed -E 's/^[0-9]+: ([^ ]+) .*/\1/'); do
    externals="${externals}external: $iface\\n"
done
sed "s/^#external-lines/$externals/" -i /run/danted.conf

# 监控 VPN 接口并启动 danted
(while true; do
    sleep 5
    VPN_IFACE=""
    
    if ip link show trustaccess >/dev/null 2>&1; then
        VPN_IFACE="trustaccess"
    elif ip link show tun0 >/dev/null 2>&1; then
        VPN_IFACE="tun0"
    fi
    
    if [ -n "$VPN_IFACE" ] && ! pgrep -f danted >/dev/null 2>&1; then
        echo "[$(date)] Starting danted (VPN interface: $VPN_IFACE)"
        chmod a+w /tmp
        su daemon -s /bin/sh -c "/usr/sbin/danted -f /run/danted.conf"
        
        # 配置 NAT
        iptables -t nat -C POSTROUTING -o $VPN_IFACE -j MASQUERADE 2>/dev/null || \
            iptables -t nat -A POSTROUTING -o $VPN_IFACE -j MASQUERADE
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A INPUT -i $VPN_IFACE -p tcp -j DROP 2>/dev/null || true
        
        echo "[$(date)] danted started on port 1080"
        break
    fi
done) &

# 创建日志目录
mkdir -p /var/log/lighttpd

# 启动 Web 管理
echo "[$(date)] Starting Web UI on port 8080"
lighttpd -f /etc/lighttpd/lighttpd.conf

echo "[$(date)] Container ready"
echo "Web UI: http://localhost:8080"
echo "SOCKS5: localhost:1080 (after VPN connection)"

tail -f /dev/null
