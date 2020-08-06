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

## License

[MIT](https://github.com/jianyun8023/openwrt_action/blob/master/LICENSE) © jianyun8023
