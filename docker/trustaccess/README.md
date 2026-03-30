# TrustAccess VPN Docker

将 TrustAccess Linux VPN 客户端（v3.2.38.8）封装为 Docker 容器，提供 Web 管理界面和 SOCKS5 代理出口。

## 功能特性

- 🌐 **Web 管理界面** - 浏览器一键连接/断开
- 🔌 **SOCKS5 代理** - 自动配置代理（端口 1080）
- 🚀 **自动启动** - 容器启动后自动运行 VPN 服务
- 📊 **状态监控** - 实时显示连接状态、路由信息
- 📁 **配置持久化** - 支持挂载配置目录
- 🔒 **安全隔离** - 完全容器化部署

## 快速开始

### 1. 运行容器

**Intel/AMD64 系统：**
```bash
docker run -d \
  --name trustaccess \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 8080:8080 \
  -p 1080:1080 \
  -v ./conf:/usr/local/trustaccess/etc \
  -v ./logs:/tmp \
  ghcr.io/jianyun8023/docker-trustaccess:latest
```
> ⚠️ **Apple Silicon 用户注意**：必须添加 `--platform linux/amd64` 参数

### 2. 配置 VPN

首次运行需要配置 VPN 连接信息：

```bash
# 进入容器运行配置工具
docker exec -it trustaccess /usr/local/trustaccess/bin/cmdconfTool

# 按提示输入：服务器地址、用户名、密码等
```

### 3. 访问 Web 界面

打开浏览器访问：**http://localhost:8080**

- 点击"连接 VPN"按钮建立连接
- 实时查看连接状态和路由信息

## Docker Compose

推荐使用 Docker Compose 管理：

```yaml
version: '3'

services:
  trustaccess:
    image: ghcr.io/jianyun8023/docker-trustaccess:latest
    container_name: trustaccess
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "8080:8080"
      - "1080:1080"
    volumes:
      - ./conf:/usr/local/trustaccess/etc
```

启动服务：

```bash
docker-compose up -d
```

## 架构说明

```
┌─────────────────────────────────────────────────┐
│              Docker Container                    │
│                                                  │
│  ┌──────────────┐      ┌──────────────────┐    │
│  │   lighttpd   │◄─────│  Web Interface   │    │
│  │   (Port 8080)│      │  (HTML/JS)       │    │
│  └──────┬───────┘      └──────────────────┘    │
│         │ CGI API                                │
│         ▼                                        │
│  ┌────────────────────┐                         │
│  │ trustaccess-       │                         │
│  │ serverd            │───┐                     │
│  └────────────────────┘   │                     │
│                            ▼                     │
│                     ┌─────────────┐             │
│                     │ trustaccess │             │
│                     │ (VPN Tunnel)│             │
│                     └──────┬──────┘             │
│                            │                     │
│                            ▼                     │
│                     ┌─────────────┐             │
│                     │   danted    │             │
│                     │  (SOCKS5)   │             │
│                     │  Port 1080  │             │
│                     └─────────────┘             │
└─────────────────────────────────────────────────┘
         │                          │
         │ HTTP:8080               │ SOCKS5:1080
         ▼                          ▼
    Web Browser              Applications
```

## 端口与挂载

### 端口说明

| 端口 | 协议 | 说明 |
|------|------|------|
| 8080 | HTTP | Web 管理界面 |
| 1080 | TCP | SOCKS5 代理服务 |

### 目录挂载

| 容器路径 | 说明 | 推荐挂载 |
|----------|------|----------|
| `/usr/local/trustaccess/etc` | VPN 配置文件（加密） | `./conf` |
| `/tmp` | 运行日志 | `./logs` |

## 常见问题

**Q: 首次运行如何配置 VPN？**

A: 执行 `docker exec -it trustaccess /usr/local/trustaccess/bin/cmdconfTool`，按提示输入配置。

**Q: 如何重新配置？**

A: 再次运行 `cmdconfTool`，选择 `y` 重新配置。

**Q: SOCKS5 代理需要认证吗？**

A: 不需要，danted 配置为无认证模式。

**Q: VPN 连接失败怎么办？**

A: 
1. 检查配置：`docker exec trustaccess ls -l /usr/local/trustaccess/etc/cmdclient.conf`
2. 查看日志：`docker logs trustaccess` 或通过 Web 界面查看
3. 参考 [CONFIG.md](CONFIG.md) 完整故障排查指南

**Q: Apple Silicon Mac 上运行注意事项？**

A: 必须添加 `--platform linux/amd64`，因为 TrustAccess 仅支持 amd64 架构。

## 技术栈

- 基础镜像: Debian 12 Slim
- Web 服务器: lighttpd
- SOCKS5 代理: dante-server
- VPN 客户端: TrustAccess v3.2.38.8

## 安全建议

1. **限制访问** - 不要将 8080 端口暴露到公网
2. **配置持久化** - 使用 volume 挂载避免配置丢失
3. **定期备份** - 备份 `./conf` 目录
4. **网络隔离** - 建议在单独的 Docker 网络中运行
