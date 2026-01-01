# 多阶段构建：构建阶段
FROM rust:1-slim as builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY . .

# 安装mdbook和mdbook-admonish
RUN cargo install mdbook --version 0.4.52 && \
    cargo install mdbook-admonish --version 1.20.0

# 构建书籍
RUN mdbook build

# 生产环境阶段
FROM nginx:alpine

# 复制构建好的书籍到nginx目录
COPY --from=builder /app/book /usr/share/nginx/html

# 复制nginx配置（可选）
COPY nginx.conf /etc/nginx/nginx.conf

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]