#!/bin/bash

[ -n "$CHECK_SYSTEM_ONLY" ] && detect-tun.sh
detect-iptables.sh
. "$(which detect-route.sh)"
[ -n "$CHECK_SYSTEM_ONLY" ] && exit

cp /etc/danted.conf.sample /run/danted.conf
externals=""
for iface in $({ ip -f inet -o addr; ip -f inet6 -o addr; } | sed -E 's/^[0-9]+: ([^ ]+) .*/\1/'); do
	externals="${externals}external: $iface\\n"
done
sed s/^#external-lines/"$externals"/ -i /run/danted.conf
# 在虚拟网络设备 tun0 打开时运行 danted 代理服务器
[ -n "$NODANTED" ] || (while true
do
sleep 5
[ -d /sys/class/net/tun0 ] && {
	chmod a+w /tmp
	open_port 1080
	su daemon -s /usr/sbin/danted -f /run/danted.conf
	close_port 1080
}
done
)&
open_port 8888
tinyproxy -c /etc/tinyproxy.conf

iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# 拒绝 tun0 侧主动请求的连接.
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i tun0 -p tcp -j DROP

# 删除深信服可能生成的一条 iptables 规则，防止其丢弃传出到宿主机的连接
# 感谢 @stingshen https://github.com/Hagb/docker-easyconnect/issues/6
# ( while true; do sleep 5 ; iptables -D SANGFOR_VIRTUAL -j DROP 2>/dev/null ; done )&

if [ -n "$_EC_CLI" ]; then
	ln -s /usr/share/sangfor/EasyConnect/resources/{conf_${EC_VER},conf}
	exec start-sangfor.sh
fi

[ -n "$EXIT" ] && MAX_RETRY=0

# 登录信息持久化处理
## 持久化配置文件夹 感谢 @hexid26 https://github.com/Hagb/docker-easyconnect/issues/21
[ -d ~/conf ] || cp -a /usr/share/sangfor/EasyConnect/resources/conf_backup ~/conf
[ -e ~/easy_connect.json ] && mv ~/easy_connect.json ~/conf/easy_connect.json # 向下兼容
## 默认使用英语：感谢 @forest0 https://github.com/Hagb/docker-easyconnect/issues/2#issuecomment-658205504
[ -e ~/conf/easy_connect.json ] || echo '{"language": "en_US"}' > ~/conf/easy_connect.json

export DISPLAY

if [ "$TYPE" != "X11" -a "$TYPE" != "x11" ]
then
	# container 再次运行时清除 /tmp 中的锁，使 container 能够反复使用。
	# 感谢 @skychan https://github.com/Hagb/docker-easyconnect/issues/4#issuecomment-660842149
	rm -rf /tmp
	mkdir /tmp

	# ==================== KasmVNC 配置 ====================
	VNC_USER_NAME=${VNC_USER:-vncuser}
	VNC_USER_PASSWORD=${VNC_PASSWORD:-password}
	VNC_USER_PROTOCOL=${VNC_PROTOCOL:-http}

	find_kasmvnc_bin() {
		local candidate=""
		for candidate in \
			kasmvncserver \
			/opt/kasmvnc/bin/kasmvncserver \
			/usr/bin/kasmvncserver \
			/usr/local/bin/kasmvncserver \
			/opt/kasmvnc/bin/vncserver \
			/usr/bin/vncserver \
			/usr/local/bin/vncserver; do
			if command -v "$candidate" >/dev/null 2>&1; then
				command -v "$candidate"
				return 0
			fi
			if [ -x "$candidate" ]; then
				echo "$candidate"
				return 0
			fi
		done
		return 1
	}

	find_kasmvnc_passwd_bin() {
		local candidate=""
		for candidate in \
			kasmvncpasswd \
			/opt/kasmvnc/bin/kasmvncpasswd \
			/usr/bin/kasmvncpasswd \
			/usr/local/bin/kasmvncpasswd; do
			if command -v "$candidate" >/dev/null 2>&1; then
				command -v "$candidate"
				return 0
			fi
			if [ -x "$candidate" ]; then
				echo "$candidate"
				return 0
			fi
		done
		return 1
	}

	KASMVNC_SERVER_BIN=$(find_kasmvnc_bin || true)
	KASMVNC_PASSWD_BIN=$(find_kasmvnc_passwd_bin || true)

	if [ -z "$KASMVNC_SERVER_BIN" ] || [ -z "$KASMVNC_PASSWD_BIN" ]; then
		echo "KasmVNC binaries not found. Please verify KasmVNC installation and PATH."
		echo "KASMVNC_SERVER_BIN=$KASMVNC_SERVER_BIN"
		echo "KASMVNC_PASSWD_BIN=$KASMVNC_PASSWD_BIN"
		exit 1
	fi

	# 清理可能存在的旧锁文件
	rm -f /tmp/.X0-lock
	rm -f /tmp/.X11-unix/X0

	# 创建 KasmVNC 用户
	echo "Creating KasmVNC user: $VNC_USER_NAME"
	echo -e "$VNC_USER_PASSWORD\n$VNC_USER_PASSWORD\n" | "$KASMVNC_PASSWD_BIN" -u $VNC_USER_NAME -w -r

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
	open_port 5900
	"$KASMVNC_SERVER_BIN" :0 -geometry 1280x720 -depth 24
	DISPLAY=:0

	# 等待 X 会话可用，避免 GTK 提前启动失败
	for i in $(seq 1 20); do
		if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
			break
		fi
		sleep 1
	done

	# 将 easyconnect 的密码放入粘贴板中，应对密码复杂且无法保存的情况 (eg: 需要短信验证登录)
	# 感谢 @yakumioto https://github.com/Hagb/docker-easyconnect/pull/8
	echo "$ECPASSWORD" | DISPLAY=:0 xclip -selection c
fi

exec start-sangfor.sh
