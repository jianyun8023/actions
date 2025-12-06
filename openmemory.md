# OpenMemory 项目指南 - jianyun8023/actions

## 项目概述

**项目类型**: 基于 GitHub Actions 的自动化 Docker 镜像构建系统  
**主要功能**: 构建和维护多个实用的容器化应用（VPN、代理、工具类）  
**技术栈**: Docker, Docker Buildx, GitHub Actions, GHCR  
**镜像仓库**: ghcr.io/jianyun8023, Docker Hub (jianyun8023)

### 核心特性
- 🐳 多架构支持：linux/amd64, linux/arm64
- 🤖 GitHub Actions 自动化构建
- 📦 GHCR 和 Docker Hub 双仓库发布
- 🔒 VPN 客户端容器化（iNode, EasyConnect）
- 📚 工具类应用（Book Helper, Snell）

## 项目架构

### 目录结构
```
actions/
├── .github/workflows/           # CI/CD 工作流
│   ├── build-inode.yml         # iNode VPN 镜像构建
│   ├── build-easy-connect-image.yml  # EasyConnect 镜像构建
│   └── build-book-helper.yml   # Book Helper 镜像构建
├── docker/
│   ├── inode/                  # iNode VPN 客户端 (VNC + SOCKS5)
│   └── book-helper/            # 图书下载管理工具
├── easy-connect/               # EasyConnect VPN 客户端
├── snell/                      # Snell 代理服务器
├── AGENTS.md                   # 多智能体开发计划
└── README.md                   # 项目文档
```

### CI/CD 架构
- **触发方式**: 手动触发（workflow_dispatch）
- **构建工具**: Docker Buildx
- **平台支持**: linux/amd64, linux/arm64
- **镜像标签**: 版本号 + latest
- **认证**: GitHub Secrets (DOCKERHUB_TOKEN, GITHUB_TOKEN)

## User Defined Namespaces

- vpn-clients
- proxy-services
- utility-tools
- cicd-workflows

## Docker 镜像组件

### 1. iNode VPN (docker-inode)
**位置**: `docker/inode/`  
**用途**: iNode VPN 客户端容器化，支持 VNC 远程访问和 SOCKS5 代理  
**架构**: linux/amd64, linux/arm64  
**镜像**: `ghcr.io/jianyun8023/docker-inode:latest`  
**端口**:
- 5900: VNC 服务
- 1080: SOCKS5 代理

**特性**:
- 基于 Debian
- 包含 VNC 服务器（VNC_PASSWORD 环境变量）
- 内置 Dante SOCKS5 代理
- TUN 设备支持（需要 NET_ADMIN 权限）
- 持久化配置（/opt/apps/.../7000）

### 2. EasyConnect (docker-easyconnect)
**位置**: `easy-connect/`  
**用途**: 深信服 EasyConnect VPN 客户端  
**架构**: linux/amd64  
**镜像**: `ghcr.io/jianyun8023/docker-easyconnect:latest`  
**特性**:
- fake-hwaddr 多阶段构建（伪装硬件地址）
- 下载官方 EasyConnect deb 包
- 支持多种代理模式（SOCKS5, tinyproxy）
- iptables 路由检测脚本

### 3. Book Helper (bookhunter + bookimporter)
**位置**: `docker/book-helper/`  
**用途**: 图书搜索下载和 Calibre 导入工具  
**架构**: linux/amd64, linux/arm64  
**镜像**: 未在工作流中（需要添加）  
**特性**:
- 基于 Debian bookworm
- 包含 bookhunter (v0.14.5)
- 包含 bookimporter (v0.1.0)
- 集成 Calibre 工具链

### 4. Snell Proxy
**位置**: `snell/`  
**用途**: Snell 协议代理服务器  
**架构**: linux/amd64  
**镜像**: 未在工作流中（需要添加）  
**特性**:
- 基于 Alpine
- Snell v4.1.1
- 随机密钥生成（SNELL_PSK）
- 默认端口 6333

### 5. OpenMemory (NEW ✨)
**位置**: `docker/openmemory/`  
**用途**: 个人 LLM 记忆层 - 私有、便携且开源  
**架构**: linux/amd64, linux/arm64  
**镜像**: 
- API: `ghcr.io/jianyun8023/openmemory-api:latest`
- UI: `ghcr.io/jianyun8023/openmemory-ui:latest`

**核心组件**:
- **API**: Python FastAPI + mem0ai + Alembic (数据库迁移)
- **UI**: Next.js 15 + React 19 + TypeScript + Redux
- **数据库**: SQLite (本地) + Qdrant (向量数据库)

**端口**:
- 8765: API 服务
- 3000: Web 界面
- 6333: Qdrant REST API
- 6334: Qdrant gRPC

**特性**:
- 🔒 本地存储，数据安全
- 🐳 多架构支持（amd64, arm64）
- 📡 支持 MCP 协议（Model Context Protocol）
- 🎨 现代化 Web 管理界面
- 🔌 多模型支持（OpenAI, Anthropic, Ollama, DeepSeek）
- ⚡ FastAPI 异步架构
- 📊 健康检查和非 root 用户运行

**数据持久化**:
- `/var/lib/openmemory`: SQLite 数据库
- `/qdrant/storage`: 向量数据

**工作流**: `.github/workflows/build-openmemory-image.yml`（双镜像构建）

**部署文档**: `docker/openmemory/README.md`

## 开发模式与规范

### GitHub Actions 工作流模式

**标准模式 1: Buildx 多架构** (iNode)
```yaml
- workflow_dispatch 手动触发
- Docker Buildx + QEMU
- 平台: linux/amd64, linux/arm64
- 推送: GHCR + Docker Hub
- 标签: VERSION + latest
```

**标准模式 2: 多阶段构建** (EasyConnect)
```yaml
- 先构建 fake-hwaddr 基础镜像
- 再构建主应用镜像（--build-arg EC_URL）
- 仅推送到 GHCR
- 手动 docker tag + push
```

### Dockerfile 模式

**模式 A: 简单 Alpine** (Snell)
- 单阶段构建
- 下载预编译二进制
- 最小化镜像

**模式 B: Debian 工具链** (Book Helper)
- 基于 Debian bookworm
- 多工具集成
- ARG 参数化版本
- TARGETARCH 多架构支持

**模式 C: 复杂桌面应用** (iNode, EasyConnect)
- 包含 VNC/X11 服务
- supervisord 进程管理
- 启动脚本和路由检测
- 需要特权权限（NET_ADMIN, /dev/net/tun）

## 项目模式与约定

### 命名规范
- **镜像名**: `docker-<service-name>` (例: docker-inode)
- **工作流**: `build-<service-name>-image.yml`
- **镜像标签**: `ghcr.io/jianyun8023/<image-name>:<version|latest>`

### 版本管理
- 使用语义化版本号（如 7.3-e0626, 7.6.7）
- 同时推送版本标签和 latest 标签
- 在工作流 env 中定义 VERSION

### 安全与认证
- GITHUB_TOKEN: 自动注入，用于 GHCR 推送
- DOCKERHUB_TOKEN: Secrets 中配置，用于 Docker Hub
- 使用 docker/login-action@v3 登录

## 当前开发计划

### 阶段 0: 项目清理 ✅ (已完成)
- ✅ 删除 OpenWrt 相关内容（openwrt/ 目录）
- ✅ 删除废弃工作流（Pulsar, DSM, 订阅转换）
- ✅ 删除 docker/atmosphere, docker/pulsar, dsm/
- ✅ 删除 .drone.yml, simple.ini
- ✅ 更新 .gitignore
- **提交**: 83a7900

### 阶段 1: OpenMemory 镜像构建 ✅ (已完成 - 2025-12-06)
- ✅ 创建 docker/openmemory/api/Dockerfile（多架构，多阶段构建）
- ✅ 创建 docker/openmemory/ui/Dockerfile（多架构，多阶段构建）
- ✅ 编写 build-openmemory-image.yml 工作流（双镜像并行构建）
- ✅ 多架构支持（linux/amd64, linux/arm64）
- ✅ docker-compose.yml（OpenMemory API + UI + Qdrant）
- ✅ 创建详细部署文档（docker/openmemory/README.md）
- ✅ 添加 .dockerignore 优化构建上下文
- ✅ 添加 HEALTHCHECK 指令
- ✅ 非 root 用户运行
- ✅ 快速启动脚本（start.sh）
- ✅ 环境变量示例（env.example）
- **提交**: 2fed5e4
- **镜像**:
  - ghcr.io/jianyun8023/openmemory-api:latest
  - ghcr.io/jianyun8023/openmemory-ui:latest

### 阶段 2: 文档更新 ⏳ (下一步)
- 更新 README.md（移除 OpenWrt，添加 OpenMemory）
- 添加 OpenMemory 使用说明
- 完善各镜像文档
- 添加部署示例和故障排查指南

### 阶段 3: 构建标准化 ⏳ (规划中)
- 审查现有 Dockerfile（iNode, EasyConnect, Book Helper, Snell）
- 统一 Dockerfile 最佳实践（参考 OpenMemory）
- 标准化多阶段构建模式
- 为所有镜像添加 HEALTHCHECK
- 为 book-helper 和 snell 创建工作流
- 优化 EasyConnect 工作流（使用 build-push-action@v6）
- 创建 .dockerignore 模板

## 技术债务与改进点

### 待修复
- [ ] book-helper 和 snell 缺少 GitHub Actions 工作流
- [ ] EasyConnect 工作流使用旧的手动 docker 命令（未使用 docker/build-push-action）
- [ ] 部分 Dockerfile 缺少 HEALTHCHECK
- [ ] 缺少 .dockerignore 文件

### 待优化
- [ ] 统一所有工作流为 docker/build-push-action@v6
- [ ] 添加构建缓存策略（cache-from, cache-to）
- [ ] 添加镜像安全扫描（Trivy）
- [ ] 标准化基础镜像选择（Alpine vs Debian）

## 关键配置与环境变量

### iNode VPN
```bash
VNC_PASSWORD=123456    # VNC 访问密码
NET_ADMIN cap + /dev/net/tun  # 必需权限
端口: 5900 (VNC), 1080 (SOCKS5)
```

### EasyConnect
```bash
EC_URL=<下载地址>      # 构建时指定 EasyConnect deb 包
VERSION=7.6.7         # 当前版本
```

### Snell
```bash
SNELL_VERSION=4.1.1   # Snell 版本
SNELL_PSK=RANDOM_KEY  # 预共享密钥
SNELL_PORT=6333       # 监听端口
```

## 相关链接

- **GitHub 仓库**: https://github.com/jianyun8023/actions
- **GHCR**: https://github.com/jianyun8023?tab=packages
- **参考项目**:
  - Hagb/docker-easyconnect
  - bookstairs/bookhunter
  - Snell (https://dl.nssurge.com)

---

**最后更新**: 2025-12-06  
**维护者**: jianyun8023

