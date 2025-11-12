# Multi-stage build for WireTuner PDF Export Worker

# Stage 1: Build
FROM rust:1.75-alpine AS builder

WORKDIR /build

# Install build dependencies for Alpine
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Create dummy main to cache dependencies
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy source code
COPY src ./src

# Build for release
RUN cargo build --release

# Stage 2: Runtime
FROM alpine:3.18

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    libgcc

# Copy binary from builder
COPY --from=builder /build/target/release/worker-export /app/worker-export

# Create non-root user
RUN adduser -D -u 1000 worker && \
    chown -R worker:worker /app

USER worker

# Environment defaults
ENV RUST_LOG=info \
    REDIS_URL=redis://redis:6379 \
    WORKER_CONCURRENCY=4 \
    OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
    OTEL_SERVICE_NAME=pdf-export-worker

# Expose Redis port (for documentation purposes)
EXPOSE 6379

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -f worker-export || exit 1

CMD ["/app/worker-export"]
