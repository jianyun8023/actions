# Actions-OpenWrt

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/jianyun8023/openwrt_action/blob/master/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/jianyun8023/openwrt_action.svg?style=flat-square&label=Stars&logo=github)](https://github.com/jianyun8023/openwrt_action/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jianyun8023/openwrt_action.svg?style=flat-square&label=Forks&logo=github)](https://github.com/jianyun8023/openwrt_action/fork)

使用GitHub Actions构建OpenWrt系统
--------

> 个人自用的系统，精简一些不常用的包。

基于[Lean's OpenWrt](https://github.com/coolsnowwolf/lede)源码编译


修改默认lan的IP为192.168.2.1
更换默认主题为Argon

## 精简列表
- 网易云音乐解锁`luci-app-unblockmusic`
- Zerotier虚拟网络`luci-app-zerotier`
- 迅雷快鸟`luci-app-xlnetacc`
- ipSec虚拟网络`luci-app-ipsec-vpnd`
- FTP服务端`luci-app-vsftpd`


## 新增APP
- luci版v2ray [luci-app-v2ray](https://github.com/kuoruan/luci-app-v2ray)
- 微信消息推送server酱 [luci-app-serverchan](https://github.com/tty228/luci-app-serverchan)
- ~~AdGuardHome广告过滤 [luci-app-adguardhome](https://github.com/rufengsuixing/luci-app-adguardhome)~~
- Passwall


## 构建脚本参考
- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
- [KFERMercer](https://github.com/KFERMercer/OpenWrt-CI)
- [hyird](https://github.com/hyird/Action-Openwrt)

## Acknowledgments

- [Microsoft](https://www.microsoft.com)
- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub](https://github.com)
- [GitHub Actions](https://github.com/features/actions)
- [tmate](https://github.com/tmate-io/tmate)
- [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [csexton/debugger-action](https://github.com/csexton/debugger-action)
- [Cisco](https://www.cisco.com/)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)

## License

[MIT](https://github.com/jianyun8023/openwrt_action/blob/master/LICENSE) © jianyun8023
