#!/bin/bash

# 简单的 HTTP 服务器 - 提供 VPN 管理 Web 界面
# 使用 busybox httpd + shell CGI

PORT=8080
WEB_ROOT=/opt/webui
CGI_BIN=/opt/webui/cgi-bin

# 创建目录结构
mkdir -p $WEB_ROOT $CGI_BIN

# 创建主页面
cat > $WEB_ROOT/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSL VPN Client</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh; color: #e0e0e0; padding: 20px;
        }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { text-align: center; margin-bottom: 30px; color: #4fc3f7; }
        .card {
            background: rgba(255,255,255,0.05); border-radius: 12px;
            padding: 20px; margin-bottom: 20px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .card h2 { font-size: 16px; color: #90caf9; margin-bottom: 15px; }
        .status { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
        .status-dot { width: 12px; height: 12px; border-radius: 50%; }
        .status-dot.connected { background: #4caf50; box-shadow: 0 0 10px #4caf50; }
        .status-dot.disconnected { background: #f44336; }
        .info-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05); }
        .info-label { color: #9e9e9e; }
        .info-value { color: #fff; font-family: monospace; }
        .btn-group { display: flex; gap: 10px; flex-wrap: wrap; }
        .btn {
            flex: 1; min-width: 120px; padding: 12px 20px;
            border: none; border-radius: 8px; cursor: pointer;
            font-size: 14px; font-weight: 500; transition: all 0.2s;
        }
        .btn-primary { background: #4fc3f7; color: #1a1a2e; }
        .btn-primary:hover { background: #29b6f6; }
        .btn-danger { background: #ef5350; color: #fff; }
        .btn-danger:hover { background: #f44336; }
        .btn-secondary { background: rgba(255,255,255,0.1); color: #e0e0e0; }
        .btn-secondary:hover { background: rgba(255,255,255,0.2); }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; color: #9e9e9e; font-size: 14px; }
        .form-group input, .form-group select {
            width: 100%; padding: 10px 12px; border-radius: 6px;
            border: 1px solid rgba(255,255,255,0.2); background: rgba(0,0,0,0.3);
            color: #fff; font-size: 14px;
        }
        .form-group input:focus { outline: none; border-color: #4fc3f7; }
        .log-box {
            background: #0d1117; border-radius: 8px; padding: 15px;
            font-family: monospace; font-size: 12px; max-height: 200px;
            overflow-y: auto; white-space: pre-wrap; color: #8b949e;
        }
        .toast {
            position: fixed; bottom: 20px; right: 20px; padding: 12px 20px;
            border-radius: 8px; color: #fff; font-size: 14px;
            transform: translateY(100px); opacity: 0; transition: all 0.3s;
        }
        .toast.show { transform: translateY(0); opacity: 1; }
        .toast.success { background: #4caf50; }
        .toast.error { background: #f44336; }
        .loading { display: inline-block; width: 16px; height: 16px; border: 2px solid rgba(255,255,255,0.3); border-top-color: #fff; border-radius: 50%; animation: spin 1s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 SSL VPN Client</h1>
        
        <div class="card">
            <h2>连接状态</h2>
            <div class="status">
                <div class="status-dot" id="statusDot"></div>
                <span id="statusText">检查中...</span>
            </div>
            <div id="vpnInfo"></div>
        </div>

        <div class="card">
            <h2>快速操作</h2>
            <div class="btn-group">
                <button class="btn btn-primary" onclick="quickConnect()" id="btnConnect">快速连接</button>
                <button class="btn btn-danger" onclick="disconnect()" id="btnDisconnect">断开连接</button>
                <button class="btn btn-secondary" onclick="refreshStatus()">刷新状态</button>
            </div>
        </div>

        <div class="card">
            <h2>手动登录</h2>
            <div class="form-group">
                <label>服务器地址</label>
                <input type="text" id="server" placeholder="例如: vpn.example.com">
            </div>
            <div class="form-group">
                <label>端口</label>
                <input type="text" id="port" placeholder="例如: 443" value="443">
            </div>
            <div class="form-group">
                <label>用户名</label>
                <input type="text" id="username" placeholder="输入用户名">
            </div>
            <div class="form-group">
                <label>密码</label>
                <input type="password" id="password" placeholder="输入密码">
            </div>
            <button class="btn btn-primary" onclick="manualConnect()" style="width:100%">登录</button>
        </div>

        <div class="card">
            <h2>SOCKS5 代理</h2>
            <div class="info-row">
                <span class="info-label">代理地址</span>
                <span class="info-value" id="proxyAddr">-</span>
            </div>
            <div class="info-row">
                <span class="info-label">代理状态</span>
                <span class="info-value" id="proxyStatus">检查中...</span>
            </div>
        </div>

        <div class="card">
            <h2>操作日志</h2>
            <div class="log-box" id="logBox">等待操作...</div>
        </div>
    </div>
    <div class="toast" id="toast"></div>

    <script>
        const API = '/cgi-bin/api.sh';
        
        function log(msg) {
            const box = document.getElementById('logBox');
            const time = new Date().toLocaleTimeString();
            box.textContent = `[${time}] ${msg}\n` + box.textContent;
        }

        function toast(msg, type = 'success') {
            const t = document.getElementById('toast');
            t.textContent = msg;
            t.className = `toast ${type} show`;
            setTimeout(() => t.classList.remove('show'), 3000);
        }

        async function api(action, params = {}) {
            const query = new URLSearchParams({ action, ...params }).toString();
            try {
                const res = await fetch(`${API}?${query}`);
                return await res.json();
            } catch (e) {
                return { success: false, error: e.message };
            }
        }

        async function refreshStatus() {
            log('刷新状态...');
            const data = await api('status');
            const dot = document.getElementById('statusDot');
            const text = document.getElementById('statusText');
            const info = document.getElementById('vpnInfo');
            
            if (data.connected) {
                dot.className = 'status-dot connected';
                text.textContent = '已连接';
                info.innerHTML = `
                    <div class="info-row"><span class="info-label">用户</span><span class="info-value">${data.user || '-'}</span></div>
                    <div class="info-row"><span class="info-label">服务器</span><span class="info-value">${data.server || '-'}</span></div>
                    <div class="info-row"><span class="info-label">内网IP</span><span class="info-value">${data.privateIp || '-'} / ${data.mask || '-'}</span></div>
                    <div class="info-row"><span class="info-label">本地地址</span><span class="info-value">${data.localIp || '-'}</span></div>
                    <div class="info-row"><span class="info-label">加密方式</span><span class="info-value">${data.encryption || '-'}</span></div>
                    <div class="info-row"><span class="info-label">连接时长</span><span class="info-value">${data.duration || '-'}</span></div>
                    <div class="info-row"><span class="info-label">流量</span><span class="info-value">↓${formatBytes(data.recvBytes)} ↑${formatBytes(data.sendBytes)}</span></div>
                    <div class="info-row"><span class="info-label">路由数量</span><span class="info-value">${data.targetCount || 0} 条</span></div>
                    <div class="info-row"><span class="info-label">版本</span><span class="info-value">${data.version || '-'}</span></div>
                `;
            } else {
                dot.className = 'status-dot disconnected';
                text.textContent = '未连接';
                info.innerHTML = '';
            }

            // 检查代理状态
            const proxyData = await api('proxy_status');
            document.getElementById('proxyAddr').textContent = 'localhost:1080';
            document.getElementById('proxyStatus').textContent = proxyData.running ? '运行中 ✓' : '未运行';
            
            log('状态已更新');
        }

        function formatBytes(bytes) {
            if (!bytes || bytes === '0') return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
        }

        async function quickConnect() {
            const btn = document.getElementById('btnConnect');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> 连接中...';
            log('执行快速连接...');
            
            const data = await api('quickconnect');
            if (data.success) {
                toast('连接成功');
                log('快速连接成功');
            } else {
                toast(data.error || '连接失败', 'error');
                log('连接失败: ' + (data.error || '未知错误'));
            }
            
            btn.disabled = false;
            btn.textContent = '快速连接';
            setTimeout(refreshStatus, 2000);
        }

        async function disconnect() {
            log('断开连接...');
            const data = await api('disconnect');
            if (data.success) {
                toast('已断开连接');
                log('断开成功');
            } else {
                toast(data.error || '断开失败', 'error');
            }
            setTimeout(refreshStatus, 1000);
        }

        async function manualConnect() {
            const server = document.getElementById('server').value;
            const port = document.getElementById('port').value;
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            
            if (!server || !port || !username || !password) {
                toast('请填写完整信息', 'error');
                return;
            }
            
            log('手动登录中...');
            const data = await api('connect', { server, port, username, password });
            if (data.success) {
                toast('登录成功');
                log('手动登录成功');
            } else {
                toast(data.error || '登录失败', 'error');
                log('登录失败: ' + (data.error || '未知错误'));
            }
            setTimeout(refreshStatus, 2000);
        }

        // 初始化
        refreshStatus();
        setInterval(refreshStatus, 30000);
    </script>
</body>
</html>
HTMLEOF


# 创建 API CGI 脚本
cat > $CGI_BIN/api.sh << 'CGIEOF'
#!/bin/bash

echo "Content-Type: application/json"
echo ""

# 解析查询参数
parse_query() {
    local query="$QUERY_STRING"
    local key="$1"
    echo "$query" | tr '&' '\n' | grep "^$key=" | cut -d'=' -f2 | sed 's/+/ /g' | busybox httpd -d
}

ACTION=$(parse_query "action")
VPN_CMD="/opt/sslvpnclient/secgateaccess"

case "$ACTION" in
    status)
        # 获取 VPN 状态
        if [ -x "$VPN_CMD" ]; then
            OUTPUT=$($VPN_CMD showinfo 2>&1)
            if echo "$OUTPUT" | grep -q "Login User:"; then
                USER=$(echo "$OUTPUT" | grep "Login User:" | cut -d':' -f2- | xargs)
                SERVER=$(echo "$OUTPUT" | grep "Server Ip/Port:" | cut -d':' -f2- | xargs)
                PRIVATE_IP=$(echo "$OUTPUT" | grep "Private IP:" | sed 's/.*Private IP: \([0-9.]*\).*/\1/')
                MASK=$(echo "$OUTPUT" | grep "Private IP:" | sed 's/.*Mask: \([0-9.]*\).*/\1/')
                LOCAL_IP=$(echo "$OUTPUT" | grep "Local Ip/Port" | cut -d':' -f2- | sed 's/^ *//')
                ENCRYPTION=$(echo "$OUTPUT" | grep "Encryption:" | cut -d':' -f2- | xargs)
                DURATION=$(echo "$OUTPUT" | grep "Duration:" | cut -d':' -f2- | xargs)
                VERSION=$(echo "$OUTPUT" | grep "Version:" | cut -d':' -f2- | xargs)
                RECV_BYTES=$(echo "$OUTPUT" | grep "Recv-bytes:" | cut -d':' -f2 | xargs)
                SEND_BYTES=$(echo "$OUTPUT" | grep "Send-bytes:" | cut -d':' -f2 | xargs)
                # 提取路由目标数量
                TARGET_COUNT=$(echo "$OUTPUT" | grep -c "Target\[")
                
                cat << EOJSON
{"connected":true,"user":"$USER","server":"$SERVER","privateIp":"$PRIVATE_IP","mask":"$MASK","localIp":"$LOCAL_IP","encryption":"$ENCRYPTION","duration":"$DURATION","version":"$VERSION","recvBytes":"$RECV_BYTES","sendBytes":"$SEND_BYTES","targetCount":$TARGET_COUNT}
EOJSON
            else
                echo '{"connected":false}'
            fi
        else
            echo '{"connected":false,"error":"VPN client not found"}'
        fi
        ;;
    
    quickconnect)
        # 快速连接（使用保存的配置）
        OUTPUT=$($VPN_CMD quickconnect 2>&1)
        if echo "$OUTPUT" | grep -qi "success\|成功\|connected"; then
            echo '{"success":true}'
        else
            ERROR=$(echo "$OUTPUT" | head -1)
            echo "{\"success\":false,\"error\":\"$ERROR\"}"
        fi
        ;;
    
    disconnect)
        # 断开连接
        OUTPUT=$($VPN_CMD disconnect 2>&1)
        echo '{"success":true}'
        ;;
    
    connect)
        # 手动连接 - 使用 expect 处理交互式输入
        SERVER=$(parse_query "server")
        PORT=$(parse_query "port")
        USERNAME=$(parse_query "username")
        PASSWORD=$(parse_query "password")
        
        if [ -z "$SERVER" ] || [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
            echo '{"success":false,"error":"缺少必要参数"}'
            exit 0
        fi
        
        # 使用 expect 脚本处理交互
        if command -v expect > /dev/null 2>&1; then
            OUTPUT=$(expect << EXPECTEOF 2>&1
spawn $VPN_CMD nationconnect
expect "请输入IP"
send "$SERVER\r"
expect "请输入端口"
send "$PORT\r"
expect "username:"
send "$USERNAME\r"
expect "Userpasswd:"
send "$PASSWORD\r"
expect {
    "初始化完成" { exit 0 }
    "失败" { exit 1 }
    "错误" { exit 1 }
    timeout { exit 2 }
}
EXPECTEOF
)
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                echo '{"success":true}'
            else
                ERROR=$(echo "$OUTPUT" | tail -1)
                echo "{\"success\":false,\"error\":\"$ERROR\"}"
            fi
        else
            # 没有 expect，尝试使用管道（可能不稳定）
            OUTPUT=$(printf "%s\n%s\n%s\n%s\n" "$SERVER" "$PORT" "$USERNAME" "$PASSWORD" | $VPN_CMD nationconnect 2>&1)
            if echo "$OUTPUT" | grep -q "初始化完成"; then
                echo '{"success":true}'
            else
                ERROR=$(echo "$OUTPUT" | grep -E "失败|错误|error" | head -1)
                echo "{\"success\":false,\"error\":\"${ERROR:-连接失败}\"}"
            fi
        fi
        ;;
    
    proxy_status)
        # 检查 SOCKS5 代理状态
        if pgrep -x danted > /dev/null 2>&1; then
            echo '{"running":true}'
        else
            echo '{"running":false}'
        fi
        ;;
    
    version)
        OUTPUT=$($VPN_CMD version 2>&1)
        echo "{\"version\":\"$OUTPUT\"}"
        ;;
    
    *)
        echo '{"error":"Unknown action"}'
        ;;
esac
CGIEOF

chmod +x $CGI_BIN/api.sh

echo "[$(date)] Starting HTTP server on port $PORT..."
cd $WEB_ROOT
busybox httpd -f -p $PORT -c /dev/null
