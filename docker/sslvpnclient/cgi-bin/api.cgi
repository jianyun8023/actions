#!/bin/bash
# SSL VPN 管理 API - CGI 脚本
# 支持的操作: status, connect, disconnect, debug

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

# JSON 转义函数
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr -d '\r'
}

# 解析 showinfo 输出为 JSON
parse_showinfo() {
    local output="$1"
    local login_user server_ip private_ip encryption duration version
    local targets=""
    
    # 使用更宽松的匹配，处理可能的空格差异
    login_user=$(echo "$output" | grep -i "Login User" | sed 's/.*Login User[[:space:]]*:[[:space:]]*//' | tr -d '\r')
    server_ip=$(echo "$output" | grep -i "Server Ip" | sed 's/.*Server Ip\/Port[[:space:]]*:[[:space:]]*//' | tr -d '\r')
    private_ip=$(echo "$output" | grep -i "Private IP" | sed 's/.*Private IP[[:space:]]*:[[:space:]]*//' | sed 's/[[:space:]]*Mask.*//' | tr -d '\r')
    encryption=$(echo "$output" | grep -i "Encryption" | sed 's/.*Encryption[[:space:]]*:[[:space:]]*//' | tr -d '\r')
    duration=$(echo "$output" | grep -i "Duration" | sed 's/.*Duration[[:space:]]*:[[:space:]]*//' | tr -d '\r')
    version=$(echo "$output" | grep -i "Version" | sed 's/.*Version[[:space:]]*:[[:space:]]*//' | tr -d '\r')
    
    # 解析路由目标
    while IFS= read -r line; do
        if echo "$line" | grep -q "Target\["; then
            target=$(echo "$line" | sed 's/.*Target\[[0-9]*\][[:space:]]*:[[:space:]]*//' | sed 's/[[:space:]]*Metric.*//' | tr -d '\r')
            if [ -n "$target" ]; then
                if [ -n "$targets" ]; then
                    targets="$targets,"
                fi
                targets="$targets\"$target\""
            fi
        fi
    done <<< "$output"
    
    # 使用 printf 确保 JSON 格式正确
    printf '{"connected":true,"info":{"loginUser":"%s","serverIp":"%s","privateIp":"%s","encryption":"%s","duration":"%s","version":"%s","targets":[%s]}}' \
        "$(json_escape "$login_user")" \
        "$(json_escape "$server_ip")" \
        "$(json_escape "$private_ip")" \
        "$(json_escape "$encryption")" \
        "$(json_escape "$duration")" \
        "$(json_escape "$version")" \
        "$targets"
}

# 处理不同的 action
case "$ACTION" in
    status)
        if check_tun0; then
            # VPN 已连接，获取详细信息
            # 切换到 VPN 客户端目录执行命令
            cd "$(dirname "$VPN_CMD")" 2>/dev/null || true
            info_output=$("$VPN_CMD" showinfo 2>&1)
            
            # 检查输出是否包含有效信息
            if echo "$info_output" | grep -qi "Login User"; then
                parse_showinfo "$info_output"
            else
                # 返回原始输出用于调试
                escaped_output=$(json_escape "$info_output")
                printf '{"connected":true,"info":null,"debug":"%s"}' "$escaped_output"
            fi
        else
            echo '{"connected":false}'
        fi
        ;;
    
    debug)
        # 调试模式：返回原始命令输出
        cd "$(dirname "$VPN_CMD")" 2>/dev/null || true
        info_output=$("$VPN_CMD" showinfo 2>&1)
        tun_exists="false"
        if check_tun0; then
            tun_exists="true"
        fi
        escaped_output=$(json_escape "$info_output")
        printf '{"vpn_cmd":"%s","tun0_exists":%s,"raw_output":"%s"}' "$VPN_CMD" "$tun_exists" "$escaped_output"
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
