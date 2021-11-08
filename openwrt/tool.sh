#!/bin/bash

source_path="./lede"

function install_dep() {
  sudo rm -rf /usr/share/dotnet /etc/mysql /etc/php /etc/apt/sources.list.d
  sudo -E apt-get -y purge azure-cli ghc* zulu* hhvm llvm* firefox google* dotnet* powershell openjdk* mysql* php* android*
  sudo -E apt-get update
  sudo -E apt-get -y install tree build-essential asciidoc binutils bzip2 gawk gettext git libncurses5-dev libz-dev patch python3 python2.7 unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib p7zip p7zip-full msmtp libssl-dev texinfo libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint device-tree-compiler g++-multilib antlr3 gperf wget curl swig rsync
  sudo -E apt-get -y autoremove --purge
  sudo -E apt-get clean
}

function clone_source_code() {
  git clone https://github.com/coolsnowwolf/lede $source_path
  cd $source_path || exit 1
  echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
}

function update_feeds() {
  cd $source_path || exit 1
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

function build_config() {
  cd $source_path || exit 1
  cp -f "../openwrt/x86_64.config" ".config"
  chmod +x ../openwrt/diy.sh
  ../openwrt/diy.sh "$(pwd)"
  du -h --max-depth=2 ./
  echo "当前配置=====start"
  cat '.config'
  echo "当前配置=====end"
}

function make_download() {
  cd $source_path || exit 1
  make defconfig
  make download -j8
  find ./dl/ -size -1024c -exec rm -f {} \;
  df -h
}

function compile_firmware() {
  cd $source_path || exit 1
  make -j$(nproc) || make -j1 V=s
  if [ $? -eq 0 ]; then
    echo "编译完成"
  else
    echo "编译完成！"
  fi
  echo "======================="
  echo "Space usage:"
  echo "======================="
  df -h
  echo "======================="
  du -h --max-depth=1 ./ --exclude=build_dir --exclude=bin
  du -h --max-depth=1 ./build_dir
  du -h --max-depth=1 ./bin
}

function parse_env() {
  case "$1" in
  install_dep)
    install_dep $2
    ;;
  clone)
    clone_source_code $2
    ;;
  update_feeds)
    update_feeds $2
    ;;
  build_config)
    build_config $2
    ;;
  make_download)
    make_download $2
    ;;
  compile_firmware)
    compile_firmware $2
    ;;
  *)
    echo "Usage: tool [install_dep|clone|update_feeds|build_config|make_download|compile_firmware]" >&2
    exit 1
    ;;
  esac
}
parse_env $@
