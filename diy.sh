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

echo '修改默认主题为argon'
sed -i 's/config internal themes/config internal themes\n    option Argon  \"\/luci-static\/argon\"/g' "$source_dir/feeds/luci/modules/luci-base/root/etc/config/luci"
sed -i 's/option mediaurlbase \/luci-static\/bootstrap/option mediaurlbase \/luci-static\/argon/g' "$source_dir/feeds/luci/modules/luci-base/root/etc/config/luci"

echo '增加hotplug网络自动挂载插件'
mkdir -p "$source_dir/feeds/lede/package/base-files/files/etc/hotplug.d/iface"
cat <<'EOF' >> "$source_dir/feeds/lede/package/base-files/files/etc/hotplug.d/iface/98-netmount"
#!/bin/sh

. /lib/functions.sh
network_mount() {
    local config="$1"
    local enabled
    local target
    local src
    local options
    local network
    local fstype
    local delay

    config_get_bool enabled "$config" enabled 0

    for opt in target src options network fstype delay
    do
        config_get "$opt" "$config" "$opt"
    done

    if [ "$enabled" = 1 -a "$INTERFACE" = "$network" ]
    then
        if [ "$ACTION" = "ifup" ]
        then
            if [ "$delay" -a $delay -gt 0 ]; then
                logger "NetMount: $ACTION: Sleep $delay seconds before mount"
                sleep $delay
            fi
            logger "NetMount: $ACTION: Mounting $src in $target"
            mount -t $fstype -o $options $src $target
        elif [ "$ACTION" = "ifdown" ]
        then
            logger "NetMount: $ACTION: Umounting $src from $target"
            umount $target
        elif [ "$ACTION" = "ifupdate" ]
        then
            logger "NetMount: $ACTION: DHCP renew. Leaving $src mounted in $target"
        else
            logger "NetMount: Unknown action $ACTION: Leaving $src mounted in $target"
        fi
    fi
}

config_load fstab
config_foreach network_mount netmount
EOF

chmod +x "$source_dir/feeds/lede/package/base-files/files/etc/hotplug.d/iface/98-netmount"
#echo '下载AdGuardHome'
#git clone https://github.com/rufengsuixing/luci-app-adguardhome "$source_dir/package/luci-app-adguardhome"
#echo 'CONFIG_PACKAGE_luci-app-adguardhome=y' >>"$source_dir/.config"

echo '下载v2ray'
git clone https://github.com/kuoruan/luci-app-v2ray "$source_dir/package/luci-app-v2ray"
echo 'CONFIG_PACKAGE_luci-app-v2ray=m' >>"$source_dir/.config"

echo '下载ServerChan'
git clone https://github.com/tty228/luci-app-serverchan "$source_dir/package/luci-app-serverchan"
echo 'CONFIG_PACKAGE_luci-app-serverchan=y' >>"$source_dir/.config"

echo '下载dockerman'
rm -rf "$source_dir/package/lean/luci-lib-docker"
rm -rf "$source_dir/package/lean/luci-app-dockerman"
git clone https://github.com/lisaac/luci-lib-docker.git "$source_dir/package/luci-lib-docker"
git clone https://github.com/lisaac/luci-app-dockerman.git "$source_dir/package/luci-app-dockerman"
echo 'CONFIG_PACKAGE_luci-lib-docker=y' >>"$source_dir/.config"
echo 'CONFIG_PACKAGE_luci-app-dockerman=y' >>"$source_dir/.config"
