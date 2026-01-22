# SSL VPN Client Docker

将 SSL VPN 客户端封装在 Docker 容器中，通过 SOCKS5 代理访问内网资源，并提供一个**简洁的 Web 管理页面**，方便你在浏览器里管理 VPN 连接。

## 功能特性

- 🔐 SSL VPN 客户端容器化
- 🌐 SOCKS5 代理 (端口 1080)
- 🖥️ Web 管理页面 (端口 8080)
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

### Web 管理页面（推荐）

访问 `http://localhost:8080` 打开 Web 管理页面，可以：

- **查看状态**：实时显示 VPN 连接状态、分配的 IP、连接时长等
- **快速连接**：一键执行 `quickconnect`（使用保存的配置）
- **断开连接**：一键断开 VPN 连接
- **路由表**：查看 VPN 分配的路由规则

页面会每 5 秒自动刷新状态。

默认容器启动会自动执行 `secgateaccess quickconnect`（并后台重试），确保 VPN 尽快建链、创建 `tun0`，随后 SOCKS5 代理（1080）才会自动可用。

如需禁用自动连接（只想手动连），可以设置：

```bash
AUTO_QUICKCONNECT=0
```

可选：调整重试间隔（秒）：

```bash
QUICKCONNECT_RETRY_INTERVAL=10
```

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
./secgateaccess quickconnect    # 快速连接（使用保存的配置）
./secgateaccess disconnect      # 断开连接
./secgateaccess showinfo        # 查看状态
./secgateaccess version         # 版本信息
./secgateaccess changepasswd    # 修改密码
```

## 端口说明

| 端口 | 用途 |
|------|------|
| 1080 | SOCKS5 代理 |
| 8080 | Web 管理页面 |

## 架构说明（重要）

当前 `deb/Ubuntu_SSLVPNClient_Setup.deb` 为 **amd64** 安装包，因此镜像仅支持 **linux/amd64**。
如果你在 Apple Silicon（arm64）上运行，请在 `docker-compose.yml` 中指定：

```yaml
platform: linux/amd64
```

## 数据持久化

配置文件存储在 `/opt/sslvpnclient/conf`，通过 volume 挂载实现持久化。

## 注意事项

1. 容器需要 `NET_ADMIN` 权限和 `/dev/net/tun` 设备
2. 首次使用需要通过 CLI 进行登录配置（保存账号密码）
3. SOCKS5 代理在 VPN 连接成功后自动启动

## 故障排查

### VPN 无法连接
- 检查网络连通性
- 确认服务器地址和端口正确
- 查看容器日志：`docker logs sslvpn`

### SOCKS5 代理不可用
- 确认 VPN 已连接（tun0 设备存在）
- 检查 danted 进程：`docker exec sslvpn pgrep danted`

### Web 管理页面无法访问
- 确认端口映射正确
- 检查 8080 端口是否被占用
- 查看 lighttpd 日志：`docker exec sslvpn cat /var/log/lighttpd/error.log`
