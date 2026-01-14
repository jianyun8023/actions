# SSL VPN Client Docker

将 SSL VPN 客户端封装在 Docker 容器中，通过 SOCKS5 代理访问内网资源，并提供 Web 管理界面。

## 功能特性

- 🔐 SSL VPN 客户端容器化
- 🌐 SOCKS5 代理 (端口 1080)
- 🖥️ Web 管理界面 (端口 8080)
- 📁 配置持久化
- 🔄 自动重连支持

## 快速开始

### 1. 确认安装包

安装包位于 `deb/Ubuntu_SSLVPNClient_Setup.deb`，已包含在项目中。

### 2. 构建镜像

```bash
docker build -t sslvpnclient .
```

### 3. 运行容器

```bash
docker-compose up -d
```

或手动运行：

```bash
docker run -d \
  --name sslvpn \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1080:1080 \
  -p 8080:8080 \
  -v ./conf:/opt/sslvpnclient/conf \
  sslvpnclient
```

## 使用方式

### Web 管理界面

访问 `http://localhost:8080` 进行 VPN 管理：

- 查看连接状态
- 快速连接（使用保存的配置）
- 断开连接
- 查看 SOCKS5 代理状态

### SOCKS5 代理

VPN 连接成功后，可通过 `localhost:1080` 使用 SOCKS5 代理：

```bash
# curl 示例
curl --socks5 localhost:1080 http://内网地址

# 配置系统代理
export ALL_PROXY=socks5://localhost:1080
```

### CLI 命令

进入容器执行 VPN 命令：

```bash
docker exec -it sslvpn bash

# 在容器内
cd /opt/sslvpnclient
./secgateaccess quickconnect    # 快速连接
./secgateaccess disconnect      # 断开连接
./secgateaccess showinfo        # 查看状态
./secgateaccess version         # 版本信息
```

## 端口说明

| 端口 | 用途 |
|------|------|
| 1080 | SOCKS5 代理 |
| 8080 | Web 管理界面 |

## 数据持久化

配置文件存储在 `/opt/sslvpnclient/conf`，通过 volume 挂载实现持久化。

## 注意事项

1. 容器需要 `NET_ADMIN` 权限和 `/dev/net/tun` 设备
2. 首次使用需要通过 CLI 进行登录配置
3. SOCKS5 代理在 VPN 连接成功后自动启动

## 故障排查

### VPN 无法连接
- 检查网络连通性
- 确认服务器地址和端口正确
- 查看容器日志：`docker logs sslvpn`

### SOCKS5 代理不可用
- 确认 VPN 已连接（tun0 设备存在）
- 检查 danted 进程：`docker exec sslvpn pgrep danted`

### Web 界面无法访问
- 确认端口映射正确
- 检查 8080 端口是否被占用
