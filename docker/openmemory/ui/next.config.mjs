/** @type {import('next').NextConfig} */
const nextConfig = {
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  // API 代理配置 - 将 /api 请求转发到后端 API 服务
  async rewrites() {
    const apiUrl = process.env.INTERNAL_API_URL || process.env.NEXT_PUBLIC_API_URL || "http://localhost:8765";
    return [
      {
        source: '/api/:path*',
        destination: `${apiUrl}/:path*`,
      },
    ];
  },
}

export default nextConfig