# OpenMemory 环境变量注入机制说明

## 🔧 问题：为什么需要运行时环境变量注入？

Next.js 在构建时会将环境变量**硬编码**到 JavaScript 文件中。这意味着：

- ❌ **问题**: 一次构建的镜像只能用于一个特定环境
- ❌ **问题**: 修改 API URL 需要重新构建镜像
- ✅ **解决**: 使用占位符 + 运行时替换机制

## 📋 实现原理

### 步骤 1: 构建时 - 使用占位符

在 `Dockerfile` 中：

```dockerfile
# Builder stage
RUN echo "NEXT_PUBLIC_API_URL=NEXT_PUBLIC_API_URL" > .env && \
    echo "NEXT_PUBLIC_USER_ID=NEXT_PUBLIC_USER_ID" >> .env && \
    pnpm build
```

这会在构建时创建一个 `.env` 文件，内容为：
```env
NEXT_PUBLIC_API_URL=NEXT_PUBLIC_API_URL
NEXT_PUBLIC_USER_ID=NEXT_PUBLIC_USER_ID
```

**注意**: 值和键名相同！这是占位符。

### 步骤 2: Next.js 构建

Next.js 读取 `.env` 文件，将这些值嵌入到 JavaScript 代码中：

```javascript
// 构建前
const apiUrl = process.env.NEXT_PUBLIC_API_URL;

// 构建后 (硬编码)
const apiUrl = "NEXT_PUBLIC_API_URL";  // 字符串字面量
```

### 步骤 3: 运行时 - 替换占位符

容器启动时，`entrypoint.sh` 执行：

```bash
#!/bin/sh
set -e

cd /app

# 替换环境变量占位符为真实值
printenv | grep NEXT_PUBLIC_ | while read -r line ; do
  key=$(echo $line | cut -d "=" -f1)      # 例如: NEXT_PUBLIC_API_URL
  value=$(echo $line | cut -d "=" -f2)    # 例如: http://localhost:8765

  # 在所有 JS 文件中替换
  find .next/ -type f -exec sed -i "s|$key|$value|g" {} \;
done

echo "Done replacing env variables NEXT_PUBLIC_ with real values"

# 启动 Next.js
exec "$@"
```

**效果**:
```javascript
// 替换前 (构建时硬编码的)
const apiUrl = "NEXT_PUBLIC_API_URL";

// 替换后 (运行时)
const apiUrl = "http://localhost:8765";
```

## 🎯 使用示例

### 本地开发

```bash
docker run -e NEXT_PUBLIC_API_URL=http://localhost:8765 \
           -e NEXT_PUBLIC_USER_ID=admin \
           -p 3000:3000 \
           ghcr.io/jianyun8023/openmemory-ui:latest
```

### Docker Compose

```yaml
services:
  openmemory-ui:
    image: ghcr.io/jianyun8023/openmemory-ui:latest
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8765
      - NEXT_PUBLIC_USER_ID=admin
    ports:
      - "3000:3000"
```

### 生产环境（域名）

```yaml
services:
  openmemory-ui:
    image: ghcr.io/jianyun8023/openmemory-ui:latest
    environment:
      - NEXT_PUBLIC_API_URL=https://api.yourdomain.com
      - NEXT_PUBLIC_USER_ID=prod-user
    ports:
      - "3000:3000"
```

## 🔍 验证机制

### 检查环境变量是否注入

```bash
# 进入容器
docker exec -it openmemory-ui sh

# 查看环境变量
printenv | grep NEXT_PUBLIC

# 输出示例：
# NEXT_PUBLIC_API_URL=http://localhost:8765
# NEXT_PUBLIC_USER_ID=admin
```

### 检查 JavaScript 文件是否替换成功

```bash
# 进入容器
docker exec -it openmemory-ui sh

# 搜索占位符（不应该找到）
grep -r "NEXT_PUBLIC_API_URL" .next/ | head -5

# 如果看到实际的 URL (http://localhost:8765) 说明替换成功
# 如果看到 "NEXT_PUBLIC_API_URL" 字符串，说明替换失败
```

### 检查替换日志

```bash
docker logs openmemory-ui 2>&1 | grep "replacing"

# 应该看到：
# Done replacing env variables NEXT_PUBLIC_ with real values
```

## ⚠️ 注意事项

### 1. 只支持 NEXT_PUBLIC_ 前缀

`entrypoint.sh` 只会替换以 `NEXT_PUBLIC_` 开头的环境变量。

✅ **会被替换**:
- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_USER_ID`
- `NEXT_PUBLIC_CUSTOM_VALUE`

❌ **不会被替换**:
- `API_URL` (缺少前缀)
- `NEXT_API_URL` (前缀不完整)
- `PUBLIC_API_URL` (前缀不对)

### 2. 构建时占位符必须匹配

`.env` 文件中的占位符值**必须**与键名相同：

✅ **正确**:
```env
NEXT_PUBLIC_API_URL=NEXT_PUBLIC_API_URL
```

❌ **错误**:
```env
NEXT_PUBLIC_API_URL=__PLACEHOLDER__  # 不会被替换
```

### 3. sed 替换的限制

`sed -i` 命令会就地修改文件。如果容器以只读文件系统运行，替换会失败。

解决方案：确保 `/app/.next/` 目录可写。

### 4. 特殊字符处理

如果环境变量值包含 `|` 字符，`sed` 替换可能失败（因为使用 `|` 作为分隔符）。

如果需要支持特殊字符，可以修改 `entrypoint.sh`：

```bash
# 使用不太可能出现的分隔符
find .next/ -type f -exec sed -i "s§${key}§${value}§g" {} \;
```

## 🔄 与其他方案的对比

### 方案 1: 多次构建（传统方式）

```dockerfile
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN pnpm build
```

**优点**: 简单直接  
**缺点**: 每个环境需要单独构建镜像

### 方案 2: 运行时注入（我们的方案）

```dockerfile
# 构建时使用占位符
RUN echo "NEXT_PUBLIC_API_URL=NEXT_PUBLIC_API_URL" > .env
RUN pnpm build

# 运行时替换
ENTRYPOINT ["/entrypoint.sh"]
```

**优点**: 一次构建，多环境部署  
**缺点**: 需要理解机制

### 方案 3: Server-Side Rendering (SSR)

使用 Next.js 服务端渲染，环境变量在服务端注入。

**优点**: 真正的运行时配置  
**缺点**: 性能开销，复杂度高

## 📚 相关资源

- **Next.js 环境变量文档**: https://nextjs.org/docs/basic-features/environment-variables
- **Docker 多阶段构建**: https://docs.docker.com/build/building/multi-stage/
- **官方 OpenMemory 仓库**: https://github.com/mem0ai/mem0/tree/main/openmemory

## 🐛 常见问题排查

### 问题 1: UI 显示错误的 API URL

**症状**: UI 尝试连接到 `NEXT_PUBLIC_API_URL` (字符串) 而不是实际 URL

**原因**: 环境变量替换失败

**排查**:
```bash
# 检查环境变量
docker exec openmemory-ui printenv | grep NEXT_PUBLIC

# 检查是否替换
docker exec openmemory-ui grep -r "NEXT_PUBLIC_API_URL" .next/ | head -5

# 检查日志
docker logs openmemory-ui
```

**解决**:
1. 确认环境变量已正确设置
2. 确认 `entrypoint.sh` 有执行权限
3. 重启容器

### 问题 2: MCP 连接失败

**症状**: MCP 客户端提示 URL 包含 `PLACEHOLDER`

**原因**: 查看的是 UI 界面上的**示例代码**，不是实际 URL

**解决**: 直接使用实际的环境变量值：
```bash
# 正确
npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/admin --client cursor

# 错误（不要从 UI 复制）
npx @openmemory/install local __PLACEHOLDER__/mcp/cursor/sse/__PLACEHOLDER__ --client cursor
```

---

**最后更新**: 2025-12-06  
**维护者**: jianyun8023

