#!/bin/bash
# TrustAccess VPN Docker 构建脚本

set -e

VERSION="3.2.38.8"
IMAGE_NAME="docker-trustaccess"
REGISTRY="ghcr.io/jianyun8023"

echo "==================================="
echo "Building TrustAccess VPN Docker"
echo "Version: $VERSION"
echo "==================================="

# 检查 DEB 文件是否存在
if [ ! -f "deb/trustaccess_${VERSION}_amd64.deb" ]; then
    echo "Error: deb/trustaccess_${VERSION}_amd64.deb not found!"
    echo "Please place the DEB package in the deb/ directory."
    exit 1
fi

echo "Building Docker image for linux/amd64..."
docker buildx build \
    --platform linux/amd64 \
    --load \
    -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} \
    -t ${REGISTRY}/${IMAGE_NAME}:latest \
    .

echo ""
echo "==================================="
echo "Build completed successfully!"
echo ""
echo "Images created:"
echo "  - ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
echo "  - ${REGISTRY}/${IMAGE_NAME}:latest"
echo ""
echo "To run the container:"
echo "  docker-compose up -d"
echo ""
echo "Or manually:"
echo "  docker run -d --name trustaccess \\"
echo "    --cap-add NET_ADMIN \\"
echo "    --device /dev/net/tun \\"
echo "    -p 8080:8080 -p 1080:1080 \\"
echo "    -v ./conf:/usr/local/trustaccess/etc \\"
echo "    -v ./logs:/tmp \\"
echo "    ${REGISTRY}/${IMAGE_NAME}:latest"
echo ""
echo "Access web interface at: http://localhost:8080"
echo "==================================="
