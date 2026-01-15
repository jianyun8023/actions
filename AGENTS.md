# AI Agents 配置 - 多智能体系统 (MAS)

本文档定义了推动本项目发展的 AI 智能体团队配置。每个 Agent 负责特定的开发任务，协同工作以实现项目目标。

## 项目概述

本项目是一个**基于 GitHub Actions 的自动化 Docker 镜像构建系统**，专注于构建和维护多个实用的容器化应用。

### 当前状态
- ✅ 已有镜像：iNode VPN、EasyConnect VPN、Book Helper、Snell 代理
- ✅ CI/CD：GitHub Actions 手动触发工作流
- ✅ 多架构支持：amd64、arm64

---

## 技术栈与工具

### 核心技术
- **容器化**: Docker, Docker Compose, Docker Buildx
- **CI/CD**: GitHub Actions
- **网络**: VPN (iNode, EasyConnect), 代理 (SOCKS5, Snell)
- **应用**: Book Helper、SSL VPN Client、Snell

### 开发工具
- **镜像仓库**: GitHub Container Registry (ghcr.io)
- **多架构构建**: docker buildx
- **版本控制**: Git
- **文档格式**: Markdown

---

## 项目规范

### Docker 镜像命名
- 格式: `ghcr.io/jianyun8023/<service-name>:latest`
- 示例: `ghcr.io/jianyun8023/sslvpnclient:latest`

### 工作流命名
- 格式: `build-<service-name>-image.yml`
- 示例: `build-sslvpnclient-image.yml`

### 目录结构
```
actions/
├── docker/
│   ├── book-helper/
│   ├── inode/
│   └── sslvpnclient/
├── easy-connect/
├── snell/
└── .github/workflows/
    ├── build-inode.yml
    ├── build-easy-connect-image.yml
    ├── build-book-helper.yml
```

### Dockerfile 最佳实践
1. 使用多阶段构建（builder + runtime）
2. 优化层缓存（依赖先于代码）
3. 使用非 root 用户
4. 添加 HEALTHCHECK 指令
5. 最小化镜像体积（Alpine/Debian slim）
6. 清晰的 LABEL 元数据

### GitHub Actions 工作流规范
1. 手动触发（workflow_dispatch）
2. 支持多架构（linux/amd64, linux/arm64）
3. 推送到 GHCR
4. 使用缓存加速构建
5. 添加构建状态 badge

---
---

## 联系与反馈

如需调整 Agent 配置或开发计划，请更新本文档并提交 PR。

**Maintainer**: jianyun8023  
**Repository**: [jianyun8023/actions](https://github.com/jianyun8023/actions)  
**License**: MIT
