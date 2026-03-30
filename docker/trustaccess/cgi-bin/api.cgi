#!/bin/bash
# TrustAccess VPN 管理 API

echo "Content-Type: application/json"
echo ""

# 解析 action 参数
ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

# 查找 TrustAccess 二进制
find_bin() {
    local bin_name="$1"
    for p in \
        "/usr/local/trustaccess/$bin_name" \
        "/usr/local/trustaccess/bin/$bin_name" \
        "/usr/bin/$bin_name" \
        "/opt/trustaccess/bin/$bin_name"; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

TRUSTACCESS_BIN=$(find_bin "trustaccess-cmdclient")

# 检查接口是否存在
check_interface() {
    ip link show "$1" >/dev/null 2>&1
}

# 检查进程是否运行
check_process() {
    # pgrep 无法匹配超过 15 字符的进程名，使用 -f 匹配完整命令行
    pgrep -f "$1" >/dev/null 2>&1
}

# 获取 VPN 接口的路由信息
get_vpn_routes() {
    local iface="$1"
    local routes=""
    while IFS= read -r line; do
        route=$(echo "$line" | awk '{print $1}')
        if [ -n "$route" ] && [ "$route" != "default" ]; then
            if [ -n "$routes" ]; then
                routes="$routes,"
            fi
            routes="$routes\"$route\""
        fi
    done <<< "$(ip route show dev "$iface" 2>/dev/null)"
    echo "$routes"
}

# 获取 VPN 接口的 IP 地址
get_vpn_ip() {
    local iface="$1"
    ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}'
}

case "$ACTION" in
    status)
        serverd_running="false"
        connected="false"
        socks5="false"
        interface=""
        vpn_ip=""
        routes=""
        
        if check_process "trustaccess-serverd"; then
            serverd_running="true"
        fi
        
        if check_interface "trustaccess"; then
            connected="true"
            interface="trustaccess"
            vpn_ip=$(get_vpn_ip "trustaccess")
            routes=$(get_vpn_routes "trustaccess")
        elif check_interface "tun0"; then
            connected="true"
            interface="tun0"
            vpn_ip=$(get_vpn_ip "tun0")
            routes=$(get_vpn_routes "tun0")
        fi
        
        if check_process "danted"; then
            socks5="true"
        fi
        
        printf '{"serverd_running":%s,"connected":%s,"socks5":%s,"interface":"%s","vpn_ip":"%s","routes":[%s]}' \
            "$serverd_running" "$connected" "$socks5" "$interface" "$vpn_ip" "$routes"
        ;;
    
    connect)
        if [ -z "$TRUSTACCESS_BIN" ]; then
            echo '{"success":false,"error":"TrustAccess 客户端未找到"}'
            exit 0
        fi
        
        if ! check_process "trustaccess-serverd"; then
            echo '{"success":false,"error":"TrustAccess 服务未运行"}'
            exit 0
        fi
        
        $TRUSTACCESS_BIN --login >/dev/null 2>&1
        sleep 2
        
        if check_interface "trustaccess" || check_interface "tun0"; then
            echo '{"success":true,"message":"连接成功"}'
        else
            echo '{"success":true,"message":"连接命令已执行，请等待"}'
        fi
        ;;
    
    disconnect)
        if [ -z "$TRUSTACCESS_BIN" ]; then
            echo '{"success":false,"error":"TrustAccess 客户端未找到"}'
            exit 0
        fi
        
        $TRUSTACCESS_BIN --logout >/dev/null 2>&1
        sleep 1
        
        if ! check_interface "trustaccess" && ! check_interface "tun0"; then
            echo '{"success":true,"message":"已断开连接"}'
        else
            echo '{"success":false,"error":"断开连接失败"}'
        fi
        ;;
    
    *)
        echo '{"success":false,"error":"无效操作，支持: status, connect, disconnect"}'
        ;;
esac
