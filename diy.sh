#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================
source_dir=$1
echo "源码所在路径: "$source_dir
echo '修改网关地址'
sed -i 's/192.168.1.1/192.168.2.1/g' "$source_dir/package/base-files/files/bin/config_generate"

echo '修改时区'
sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" "$source_dir/package/base-files/files/bin/config_generate"

echo '修改默认主题'
sed -i 's/config internal themes/config internal themes\n    option Argon  \"\/luci-static\/argon\"/g' "$source_dir/feeds/luci/modules/luci-base/root/etc/config/luci"

#echo '下载AdGuardHome'
#git clone https://github.com/rufengsuixing/luci-app-adguardhome "$source_dir/package/luci-app-adguardhome"
#echo 'CONFIG_PACKAGE_luci-app-adguardhome=y' >>"$source_dir/.config"

echo '下载v2ray'
git clone https://github.com/kuoruan/luci-app-v2ray "$source_dir/package/luci-app-v2ray"
echo 'CONFIG_PACKAGE_luci-app-v2ray=m' >>"$source_dir/.config"

echo '下载ServerChan'
git clone https://github.com/tty228/luci-app-serverchan "$source_dir/package/luci-app-serverchan"
echo 'CONFIG_PACKAGE_luci-app-serverchan=y' >>"$source_dir/.config"

ls "$source_dir/feeds/luci/modules/luci-base/root/etc/hotplug.d/iface/"
echo '列出 feeds目录'
tree "$source_dir/feeds"
exit 1
