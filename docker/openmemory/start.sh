#!/bin/bash
# OpenMemory 快速启动脚本

set -e

echo "🚀 OpenMemory 快速启动脚本"
echo "================================"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未安装 Docker"
    echo "请访问 https://docs.docker.com/get-docker/ 安装 Docker"
    exit 1
fi

# 检查 Docker Compose
if ! command -v docker compose &> /dev/null; then
    echo "❌ 错误: 未安装 Docker Compose"
    echo "请访问 https://docs.docker.com/compose/install/ 安装 Docker Compose"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo ""

# 检查 .env 文件
if [ ! -f .env ]; then
    echo "⚠️  未找到 .env 文件"
    echo "📝 从 env.example 创建 .env 文件..."
    
    if [ -f env.example ]; then
        cp env.example .env
        echo "✅ 已创建 .env 文件"
        echo ""
        echo "⚠️  请编辑 .env 文件并设置以下变量："
        echo "   - OPENAI_API_KEY (必需)"
        echo "   - OPENAI_BASE_URL (可选)"
        echo ""
        read -p "按回车键继续编辑 .env 文件..." 
        ${EDITOR:-vi} .env
    else
        echo "❌ 错误: 未找到 env.example 文件"
        exit 1
    fi
fi

# 验证 OPENAI_API_KEY
source .env
if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "sk-your-openai-api-key-here" ]; then
    echo "❌ 错误: OPENAI_API_KEY 未设置或使用默认值"
    echo "请编辑 .env 文件并设置有效的 OPENAI_API_KEY"
    exit 1
fi

echo "✅ 环境变量配置有效"
echo ""

# 拉取最新镜像
echo "📥 拉取最新镜像..."
docker compose pull

echo ""
echo "🏗️  启动 OpenMemory 服务..."
docker compose up -d

echo ""
echo "⏳ 等待服务就绪..."
sleep 10

# 检查服务状态
echo ""
echo "📊 服务状态:"
docker compose ps

echo ""
echo "✅ OpenMemory 已成功启动！"
echo ""
echo "🌐 访问地址:"
echo "   - Web 界面:  http://localhost:3000"
echo "   - API 文档:  http://localhost:8765/docs"
echo "   - Qdrant:    http://localhost:6333/dashboard"
echo ""
echo "📝 常用命令:"
echo "   - 查看日志:  docker compose logs -f"
echo "   - 停止服务:  docker compose down"
echo "   - 重启服务:  docker compose restart"
echo ""
echo "📚 更多信息请查看: README.md"

