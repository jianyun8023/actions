# Github-Actions

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/jianyun8023/github_actions/blob/master/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/jianyun8023/github_actions.svg?style=flat-square&label=Stars&logo=github)](https://github.com/jianyun8023/github_actions/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jianyun8023/github_actions.svg?style=flat-square&label=Forks&logo=github)](https://github.com/jianyun8023/github_actions/fork)


## 使用GitHub Actions构建OpenWrt系统

> 个人自用的系统，精简一些不常用的包。每日凌晨两点构建。

基于[Lean's OpenWrt](https://github.com/coolsnowwolf/lede)源码编译

- 修改默认lan的IP为192.168.2.1
- 默认账户密码 `root\password`
- 默认安装python3

### 精简列表
- 网易云音乐解锁`luci-app-unblockmusic`
- Zerotier虚拟网络`luci-app-zerotier`
- 迅雷快鸟`luci-app-xlnetacc`
- ipSec虚拟网络`luci-app-ipsec-vpnd`
- FTP服务端`luci-app-vsftpd`


### 新增APP
- ~~luci版v2ray [luci-app-v2ray](https://github.com/kuoruan/luci-app-v2ray)~~
- 微信消息推送server酱 [luci-app-serverchan](https://github.com/tty228/luci-app-serverchan)
- ~~AdGuardHome广告过滤 [luci-app-adguardhome](https://github.com/rufengsuixing/luci-app-adguardhome)~~


## Fork后的仓库同步
每小时以rebase的方式同步一次[pulsar](https://github.com/apache/pulsar)的master到自己的仓库。

## docker-easy-connect
参考了 [Hagb/docker-easyconnect](https://github.com/Hagb/docker-easyconnect)配置，自己手动构建镜像
## docker-inode
环境变量 `VNC_PASSWORD=123456`
docker compose 示例
```yaml
version: '3.9'

services:
  vpn_app:
    image: ghcr.io/jianyun8023/docker-inode:latest  # 替换为你的镜像名称
    cap_add:
      - NET_ADMIN                   # 授予管理网络的能力
    devices:
      - /dev/net/tun                # 挂载 TUN 设备
    ports:
      - "5903:5900"                 # VNC 端口映射
      - "1087:1080"                 # socks5 端口映射
    volumes:
      # - ./7000:/opt/apps/com.client.inode.amd/files/clientfiles/7000 可以挂载ssl-vpn配置
    restart: unless-stopped
```
查看vpn的路由，请到容器里执行 `ip r | grep tun0`
## License

[MIT](https://github.com/jianyun8023/openwrt_action/blob/master/LICENSE) © jianyun8023
