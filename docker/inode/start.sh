#!/bin/bash
set -x
#sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
#service dbus start
#service NetworkManager start
#nohup /usr/sbin/NetworkManager --no-daemon &

# 等待 NetworkManager 启动
#sleep 5

# 检查 NetworkManager 状态
#nmcli general status

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

iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# 拒绝 tun0 侧主动请求的连接.
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i tun0 -p tcp -j DROP

/etc/init.d/iNodeAuthService restart
/opt/apps/com.client.inode.amd/files/.iNode/iNodeClient

