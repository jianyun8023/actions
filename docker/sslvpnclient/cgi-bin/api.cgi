#!/bin/bash
# SSL VPN 管理 API - CGI 脚本
# 支持的操作: status, connect, disconnect

# 输出 JSON 响应头
echo "Content-Type: application/json"
echo ""

# 解析 action 参数
ACTION=""
if [ -n "$QUERY_STRING" ]; then
    ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')
fi

# VPN 客户端路径
VPN_CMD=""
for p in \
    "/opt/sslvpnclient/secgateaccess" \
    "/opt/SSLVPNClient/secgateaccess" \
    "/usr/local/sslvpnclient/secgateaccess" \
    "/usr/local/bin/secgateaccess" \
    "/usr/bin/secgateaccess"; do
    if [ -x "$p" ]; then
        VPN_CMD="$p"
        break
    fi
done

# 检查 VPN 客户端是否存在
if [ -z "$VPN_CMD" ]; then
    echo '{"success":false,"error":"VPN 客户端未找到"}'
    exit 0
fi

# 检查 tun0 接口是否存在
check_tun0() {
    [ -d /sys/class/net/tun0 ]
}

# 解析 showinfo 输出为 JSON
parse_showinfo() {
    local output="$1"
    local login_user server_ip private_ip encryption duration version
    local targets=""
    
    login_user=$(echo "$output" | grep "Login User:" | sed 's/Login User:[[:space:]]*//')
    server_ip=$(echo "$output" | grep "Server Ip/Port:" | sed 's/Server Ip\/Port:[[:space:]]*//')
    private_ip=$(echo "$output" | grep "Private IP:" | sed 's/Private IP:[[:space:]]*//' | sed 's/[[:space:]]*Mask:.*//')
    encryption=$(echo "$output" | grep "Encryption:" | sed 's/Encryption:[[:space:]]*//')
    duration=$(echo "$output" | grep "Duration:" | sed 's/Duration:[[:space:]]*//')
    version=$(echo "$output" | grep "Version:" | sed 's/Version:[[:space:]]*//')
    
    # 解析路由目标
    while IFS= read -r line; do
        if echo "$line" | grep -q "^Target\["; then
            target=$(echo "$line" | sed 's/Target\[[0-9]*\]:[[:space:]]*//' | sed 's/[[:space:]]*Metric:.*//')
            if [ -n "$targets" ]; then
                targets="$targets,"
            fi
            targets="$targets\"$target\""
        fi
    done <<< "$output"
    
    cat <<EOF
{
    "connected": true,
    "info": {
        "loginUser": "$login_user",
        "serverIp": "$server_ip",
        "privateIp": "$private_ip",
        "encryption": "$encryption",
        "duration": "$duration",
        "version": "$version",
        "targets": [$targets]
    }
}
EOF
}

# 处理不同的 action
case "$ACTION" in
    status)
        if check_tun0; then
            # VPN 已连接，获取详细信息
            info_output=$("$VPN_CMD" showinfo 2>&1)
            if echo "$info_output" | grep -q "Login User:"; then
                parse_showinfo "$info_output"
            else
                echo '{"connected":true,"info":null}'
            fi
        else
            echo '{"connected":false}'
        fi
        ;;
    
    connect)
        # 执行快速连接
        output=$("$VPN_CMD" quickconnect 2>&1)
        exit_code=$?
        
        # 等待一小段时间让连接建立
        sleep 2
        
        if check_tun0; then
            echo '{"success":true,"message":"连接成功"}'
        else
            # 可能还在连接中，返回成功但提示等待
            echo '{"success":true,"message":"连接命令已执行，请等待连接建立"}'
        fi
        ;;
    
    disconnect)
        # 执行断开连接
        output=$("$VPN_CMD" disconnect 2>&1)
        exit_code=$?
        
        sleep 1
        
        if ! check_tun0; then
            echo '{"success":true,"message":"已断开连接"}'
        else
            echo '{"success":false,"error":"断开连接失败"}'
        fi
        ;;
    
    *)
        echo '{"success":false,"error":"无效的操作，支持: status, connect, disconnect"}'
        ;;
esac
