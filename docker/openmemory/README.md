# OpenMemory Docker 镜像

基于官方 [mem0ai/mem0](https://github.com/mem0ai/mem0/tree/main/openmemory) 仓库构建的 OpenMemory 多架构 Docker 镜像。

## 📋 项目简介

OpenMemory 是个人 LLM 记忆层 - 私有、便携且开源。您的记忆存储在本地，完全控制您的数据。构建具有个性化记忆的 AI 应用程序，同时保持数据安全。

### 特性

- 🐳 **多架构支持**: linux/amd64, linux/arm64
- 🔒 **数据安全**: 本地存储，完全控制
- 🚀 **开箱即用**: Docker Compose 一键部署
- 📡 **MCP 协议**: 支持 Model Context Protocol
- 🎨 **Web 界面**: 直观的记忆管理界面
- 🔌 **多模型支持**: OpenAI, Anthropic, Ollama, DeepSeek 等

## 🎯 快速开始

### 前提条件

- Docker 和 Docker Compose
- OpenAI API Key（或兼容的 API 服务）
- （可选）自定义模型配置文件

### 1. 下载配置文件

```bash
# 创建工作目录
mkdir openmemory && cd openmemory

# 下载 docker-compose.yml
curl -O https://raw.githubusercontent.com/jianyun8023/actions/master/docker/openmemory/docker-compose.yml
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
# 方式 1：直接创建
cat > .env << 'EOF'
# OpenAI 配置
OPENAI_API_KEY=sk-your-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1

# UI 配置
NEXT_PUBLIC_API_URL=/api
INTERNAL_API_URL=http://openmemory-api:8765
EOF

# 方式 2：导出环境变量
export OPENAI_API_KEY=sk-your-api-key-here
export OPENAI_BASE_URL=https://api.openai.com/v1
export NEXT_PUBLIC_API_URL=/api
export INTERNAL_API_URL=http://openmemory-api:8765
```

### 3. （可选）配置自定义模型

如果需要使用硅基流动、Ollama 或其他模型服务：

```bash
# 复制配置模板
cp config.json.example config.json

# 编辑配置文件（参考下方"使用自定义模型"章节）
vim config.json

# 在 docker-compose.yml 中取消注释配置挂载
# - ./config.json:/usr/src/openmemory/config.json:ro
```

### 4. 启动服务

```bash
docker compose up -d
```

### 5. 访问应用

- **Web 界面**: http://localhost:3000
- **API 文档**: http://localhost:8765/docs
- **Qdrant 控制台**: http://localhost:6333/dashboard

## 📦 镜像信息

### API 镜像

```bash
docker pull ghcr.io/jianyun8023/openmemory-api:latest
```

**架构**: linux/amd64, linux/arm64  
**基础镜像**: python:3.12-slim  
**暴露端口**: 8765

### UI 镜像

```bash
docker pull ghcr.io/jianyun8023/openmemory-ui:latest
```

**架构**: linux/amd64, linux/arm64  
**基础镜像**: node:18-alpine  
**暴露端口**: 3000

## ⚙️ 配置说明

### 架构模式

```
浏览器 → UI 服务 (Next.js) → API 服务
         (代理转发 /api/*)
```

**优势**：
- ✅ 更安全：API 服务不需要对外暴露
- ✅ 无 CORS 问题
- ✅ 统一入口，便于反向代理配置
- ✅ 浏览器只需访问 UI 地址

---

### 环境变量

#### API 服务（openmemory-api）

| 变量 | 说明 | 必需 | 默认值 |
|------|------|------|--------|
| `USER` | 用户 ID（与 UI 保持一致） | 是 | admin |
| `OPENAI_API_KEY` | OpenAI API 密钥 | 是 | - |
| `OPENAI_BASE_URL` | OpenAI API Base URL | 否 | https://api.openai.com/v1 |
| `DATABASE_URL` | SQLite 数据库路径 | 否 | sqlite:////var/lib/openmemory/openmemory.db |
| `QDRANT_HOST` | Qdrant 主机地址 | 否 | qdrant |
| `QDRANT_PORT` | Qdrant 端口 | 否 | 6333 |

#### UI 服务（openmemory-ui）

| 变量 | 说明 | 必需 | 默认值 |
|------|------|------|--------|
| `NEXT_PUBLIC_API_URL` | 浏览器端 API 地址（相对路径） | 是 | `/api` |
| `INTERNAL_API_URL` | 服务端内部 API 地址 | 否 | `http://openmemory-api:8765` |
| `NEXT_PUBLIC_USER_ID` | 用户 ID（与 API 保持一致） | 是 | `admin` |

### 端口映射

| 服务 | 容器端口 | 主机端口 | 说明 |
|------|----------|----------|------|
| openmemory-api | 8765 | 8765 | API 服务（可选暴露，用于调试） |
| openmemory-ui | 3000 | 3000 | Web 界面（对外访问入口） |
| qdrant | 6333 | 6333 | Qdrant REST API |
| qdrant | 6334 | 6334 | Qdrant gRPC |

### 数据持久化

| 卷名 | 挂载点 | 说明 |
|------|--------|------|
| `qdrant_storage` | /qdrant/storage | Qdrant 向量数据 |
| `api_data` | /var/lib/openmemory | SQLite 数据库 |

## 🎨 使用自定义模型

### 方式 1: 使用配置文件（推荐）

创建 `config.json` 并在 `docker-compose.yml` 中挂载：

```bash
# 1. 复制模板
cp config.json.example config.json

# 2. 编辑配置（例如使用硅基流动 Qwen 模型）
cat > config.json << 'EOF'
{
    "mem0": {
        "llm": {
            "provider": "openai",
            "config": {
                "model": "Qwen/Qwen2.5-7B-Instruct",
                "temperature": 0.1,
                "max_tokens": 2000,
                "api_key": "env:SILICONFLOW_API_KEY",
                "base_url": "https://api.siliconflow.cn/v1"
            }
        },
        "embedder": {
            "provider": "openai",
            "config": {
                "model": "Qwen/Qwen3-Embedding-8B",
                "api_key": "env:SILICONFLOW_API_KEY",
                "base_url": "https://api.siliconflow.cn/v1"
            }
        }
    }
}
EOF

# 3. 在 docker-compose.yml 中启用挂载
# 取消注释这一行:
# volumes:
#   - ./config.json:/usr/src/openmemory/config.json:ro

# 4. 设置环境变量
export SILICONFLOW_API_KEY="your-api-key"

# 5. 启动服务
docker compose up -d
```

### 方式 2: 仅使用环境变量（简单场景）

如果只需要更改 API Key 和 Base URL，直接在 `.env` 文件中配置：

```bash
OPENAI_API_KEY=your-api-key
OPENAI_BASE_URL=https://api.siliconflow.cn/v1
```

**注意**: 环境变量方式只能配置 API Key 和 Base URL，不能更改模型。如需使用不同模型（如 Qwen），必须使用配置文件方式。

---

## 🚀 部署场景

### 场景 1：本地开发

访问：`http://localhost:3000`

---

### 场景 2：局域网服务器

访问：`http://192.168.1.100:3000`（局域网内其他设备）

---

### 场景 3：云服务器（Nginx + SSL）

**Nginx 配置示例**：
```nginx
server {
    listen 443 ssl http2;
    server_name openmemory.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

访问：`https://openmemory.yourdomain.com`

## 🔌 MCP 客户端配置

### Cursor / Cline / Windsurf

1. 确保 OpenMemory API 服务正在运行
2. 使用以下命令配置 MCP 客户端：

```bash
npx @openmemory/install local http://localhost:8765/mcp/<client-name>/sse/<user-id> --client <client-name>
```

**示例**:

```bash
# Cursor
npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/admin --client cursor

# Cline
npx @openmemory/install local http://localhost:8765/mcp/cline/sse/admin --client cline

# Windsurf
npx @openmemory/install local http://localhost:8765/mcp/windsurf/sse/admin --client windsurf
```

### 验证连接

访问 API 文档查看 MCP 端点：
```
http://localhost:8765/docs#/MCP
```

## 🛠️ 常用命令

### 查看日志

```bash
# 所有服务
docker compose logs -f

# 指定服务
docker compose logs -f openmemory-api
docker compose logs -f openmemory-ui
docker compose logs -f qdrant
```

### 重启服务

```bash
# 重启所有服务
docker compose restart

# 重启指定服务
docker compose restart openmemory-api
```

### 停止服务

```bash
# 停止但保留数据
docker compose down

# 停止并删除数据卷
docker compose down -v
```

### 更新镜像

```bash
# 拉取最新镜像
docker compose pull

# 重新创建容器
docker compose up -d --force-recreate
```

### 进入容器

```bash
# API 容器
docker compose exec openmemory-api bash

# UI 容器
docker compose exec openmemory-ui sh
```

### 数据库迁移

```bash
# 升级到最新版本
docker compose exec openmemory-api alembic upgrade head

# 回滚一个版本
docker compose exec openmemory-api alembic downgrade -1
```

## 📊 健康检查

### API 健康检查

```bash
curl http://localhost:8765/docs
```

### UI 健康检查

```bash
curl http://localhost:3000/
```

### Qdrant 健康检查

```bash
curl http://localhost:6333/health
```

## 🔧 故障排查

### 问题 1: UI 无法访问 API

**症状**: UI 界面加载失败，提示网络错误

**解决方案**:
1. 检查 `NEXT_PUBLIC_API_URL` 是否正确配置
2. 确认 API 服务正在运行：`docker compose ps`
3. 检查防火墙设置
4. 查看日志：`docker compose logs openmemory-api`

### 问题 2: OpenAI API 调用失败

**症状**: 创建记忆时报错

**解决方案**:
1. 验证 `OPENAI_API_KEY` 是否有效
2. 检查 `OPENAI_BASE_URL` 配置（使用代理时）
3. 查看 API 日志：`docker compose logs openmemory-api`

### 问题 3: Qdrant 连接失败

**症状**: API 启动报错，无法连接 Qdrant

**解决方案**:
1. 确认 Qdrant 容器正在运行：`docker compose ps qdrant`
2. 检查网络连接：`docker compose exec openmemory-api ping qdrant`
3. 重启 Qdrant：`docker compose restart qdrant`

### 问题 4: 数据丢失

**症状**: 重启后记忆消失

**解决方案**:
1. 检查数据卷是否被删除：`docker volume ls`
2. 不要使用 `docker compose down -v`（会删除卷）
3. 备份数据库：
   ```bash
   docker compose cp openmemory-api:/var/lib/openmemory/openmemory.db ./backup.db
   ```

### 问题 5: 容器启动失败

**症状**: 容器反复重启

**解决方案**:
1. 查看详细日志：`docker compose logs --tail=100 openmemory-api`
2. 检查端口占用：`lsof -i :8765` 或 `netstat -tuln | grep 8765`
3. 验证环境变量：`docker compose config`
4. 清理并重建：
   ```bash
   docker compose down -v
   docker compose build --no-cache
   docker compose up -d
   ```

## 🔐 安全建议

1. **生产环境**:
   - 使用 Nginx 反向代理
   - 配置 HTTPS (Let's Encrypt)
   - 限制端口访问（防火墙规则）

2. **API Key 管理**:
   - 不要在 `docker-compose.yml` 中硬编码
   - 使用 `.env` 文件（添加到 `.gitignore`）
   - 定期轮换密钥

3. **数据备份**:
   ```bash
   # 备份脚本
   #!/bin/bash
   DATE=$(date +%Y%m%d_%H%M%S)
   docker compose cp openmemory-api:/var/lib/openmemory/openmemory.db ./backups/openmemory_${DATE}.db
   ```

## 📚 相关资源

- **官方仓库**: https://github.com/mem0ai/mem0/tree/main/openmemory
- **Mem0 文档**: https://docs.mem0.ai/
- **MCP 协议**: https://modelcontextprotocol.io/
- **Qdrant 文档**: https://qdrant.tech/documentation/
- **本项目仓库**: https://github.com/jianyun8023/actions

## 📝 更新日志

### 2025-12-06
- ✅ 初始版本发布
- ✅ 多架构支持（amd64, arm64）
- ✅ 基于官方 mem0ai/mem0 仓库
- ✅ 优化 Dockerfile（多阶段构建、健康检查、非 root 用户）
- ✅ 完整的 Docker Compose 配置
- ✅ 详细的部署文档

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License - 详见官方仓库

---

**维护者**: jianyun8023  
**镜像仓库**: ghcr.io/jianyun8023  
**构建系统**: GitHub Actions

