# WireTuner PDF Export Worker

Background worker service for converting SVG documents to PDF using resvg.

## Overview

This Rust-based worker processes PDF export jobs from a Redis queue, providing high-fidelity SVG-to-PDF conversion with retry logic, telemetry, and failure handling.

## Architecture

### Pipeline Diagram

```
┌─────────────────────┐
│   Flutter Client    │
│   (UI + Export)     │
└──────────┬──────────┘
           │ 1. Enqueue job (JSON over Redis)
           │    - document_id
           │    - svg_content
           │    - output_path
           ▼
┌─────────────────────┐
│       Redis         │
│   (Job Queue +      │
│   Status Store)     │
└──────────┬──────────┘
           │ 2. BLPOP dequeue
           │    (blocking with timeout)
           ▼
┌─────────────────────┐
│   Rust Worker       │
│   (Concurrent       │
│   Processing)       │
│                     │
│  ┌───────────────┐  │
│  │ SVG Parser    │  │
│  │ (usvg)        │  │
│  └───────┬───────┘  │
│          │          │
│          ▼          │
│  ┌───────────────┐  │
│  │ PDF Generator │  │
│  │ (printpdf)    │  │
│  └───────┬───────┘  │
│          │          │
│          ▼          │
│  ┌───────────────┐  │
│  │ Vector Output │  │
│  │ (resvg)       │  │
│  └───────┬───────┘  │
└──────────┼──────────┘
           │ 3. Update status (Redis)
           │ 4. Write PDF file
           ▼
┌─────────────────────┐
│   Filesystem        │
│   /exports/*.pdf    │
└─────────────────────┘
           │
           │ 5. Poll status (UI)
           ▼
┌─────────────────────┐
│  Status Response    │
│  - complete/failed  │
│  - retry_count      │
│  - error (if any)   │
└─────────────────────┘
```

### Components

- **Flutter Client**: Enqueues export jobs with SVG content and polls for completion status
- **Redis Queue**: FIFO job queue (`wiretuner:export:pdf:queue`) with blocking pop operations
- **Status Tracking**: Redis keys with 24h TTL (`wiretuner:export:pdf:status:{job_id}`)
- **Rust Worker**: Multi-threaded async worker with semaphore-based concurrency control
- **Converter**: resvg + usvg + printpdf for true vector SVG→PDF conversion
- **Telemetry**: OpenTelemetry OTLP export with spans, metrics, and error tracking

## Building

### Prerequisites

- Rust 1.75 or later
- Cargo (comes with Rust)
- pkg-config (for OpenSSL detection)
- OpenSSL development libraries

### Build from Source

```bash
# Clone the repository (if not already in it)
git clone https://github.com/WireTuner/wiretuner.git
cd wiretuner/server/worker-export

# Build in debug mode (faster compile, slower runtime)
cargo build

# Build in release mode (optimized for production)
cargo build --release

# The binary will be at:
# - Debug: target/debug/worker-export
# - Release: target/release/worker-export
```

### Running Tests

```bash
# Run unit tests only (no Redis required)
cargo test --lib

# Run all tests including integration tests (requires Redis)
docker run -d -p 6379:6379 redis:7-alpine
cargo test

# Run tests with output
cargo test -- --nocapture

# Run specific test
cargo test test_convert_simple_svg
```

### Build Optimizations

The release profile is configured for maximum performance:

```toml
[profile.release]
opt-level = 3        # Maximum optimization
lto = true           # Link-time optimization
codegen-units = 1    # Single codegen unit for better optimization
```

Expected binary sizes:
- Debug: ~15-20 MB
- Release: ~5-8 MB (with LTO)

## Running

### Prerequisites

- Redis 7.x running on `localhost:6379` (or custom `REDIS_URL`)
- OpenTelemetry collector (optional, for telemetry export)

### Configuration

Environment variables:

- `REDIS_URL`: Redis connection string (default: `redis://127.0.0.1/`)
- `WORKER_CONCURRENCY`: Number of concurrent workers (default: `4`)
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP collector endpoint (default: `http://localhost:4317`)
- `OTEL_SERVICE_NAME`: Service name for telemetry (default: `pdf-export-worker`)
- `RUST_LOG`: Log level (`error`, `warn`, `info`, `debug`, `trace`)

### Start Worker

```bash
# Development
RUST_LOG=info cargo run

# Production
RUST_LOG=warn ./target/release/worker-export
```

### Docker Deployment

#### Using Docker Compose (Recommended)

The complete stack includes Redis, the worker, and optional Jaeger telemetry:

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f worker-export

# Scale workers
docker-compose up -d --scale worker-export=3

# Stop all services
docker-compose down
```

#### Manual Docker Build

```bash
# Build image
docker build -t wiretuner/worker-export .

# Run Redis
docker run -d --name redis \
  -p 6379:6379 \
  redis:7-alpine

# Run worker with custom configuration
docker run -d --name worker-export \
  -e REDIS_URL=redis://redis:6379 \
  -e WORKER_CONCURRENCY=8 \
  -e RUST_LOG=info \
  -v $(pwd)/exports:/exports \
  --link redis:redis \
  wiretuner/worker-export
```

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | `redis://127.0.0.1/` | Redis connection string |
| `WORKER_CONCURRENCY` | `4` | Number of concurrent job processors |
| `RUST_LOG` | `info` | Log level (error, warn, info, debug, trace) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4317` | OpenTelemetry collector endpoint |
| `OTEL_SERVICE_NAME` | `pdf-export-worker` | Service name for telemetry |

## Job Format

### Enqueue Request

```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "document_id": "doc-123",
  "svg_content": "<svg xmlns=\"http://www.w3.org/2000/svg\">...</svg>",
  "output_path": "/var/exports/doc-123.pdf",
  "metadata": {
    "artboard_ids": ["ab-1", "ab-2"],
    "export_scope": "selected",
    "client_version": "0.1.0",
    "user_id": null
  },
  "status": "queued",
  "retry_count": 0,
  "created_at": "2025-11-11T12:00:00Z",
  "updated_at": "2025-11-11T12:00:00Z"
}
```

### Status Response

```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "document_id": "doc-123",
  "status": "processing",  // queued | processing | complete | failed
  "retry_count": 0,
  "created_at": "2025-11-11T12:00:00Z",
  "updated_at": "2025-11-11T12:00:05Z",
  "error": null
}
```

## Failure Handling

### Retry Logic

- Automatic retry up to 3 attempts
- Jobs re-queued with incremented `retry_count`
- Final failure after max retries exhausted
- Error messages logged to telemetry

### Error Scenarios

| Error | Handling |
|-------|----------|
| Invalid SVG | Immediate failure, no retry |
| File I/O error | Retry with backoff |
| Redis connection loss | Worker reconnects, jobs persist |
| Out of memory | Worker crash, jobs remain in queue |

## Telemetry

### Metrics Exported

- `pdf_export_job` span: Job lifecycle (queued → processing → complete/failed)
- `worker_heartbeat` span: Worker health (emitted every 10 jobs)
- Job duration (ms)
- Retry count
- Error messages

### Example OTLP Export

```json
{
  "spans": [
    {
      "name": "pdf_export_job",
      "attributes": {
        "job_id": "550e8400-e29b-41d4-a716-446655440000",
        "document_id": "doc-123",
        "status": "complete",
        "duration_ms": 1234,
        "retry_count": 0,
        "export_scope": "selected",
        "artboard_count": 2
      }
    }
  ]
}
```

## Performance

### Benchmarks

- Simple SVG (100 objects): ~50ms
- Complex SVG (1000 objects): ~500ms
- Very complex SVG (10000 objects): ~5s

### Scaling

- Horizontal: Run multiple worker instances against same Redis
- Concurrency: Adjust `WORKER_CONCURRENCY` per instance
- Queue depth monitoring: Track `queue_length` metric

## Acceptance Criteria

- ✅ Export completes with vector fidelity (resvg rendering)
- ✅ Retries on failures (up to 3 attempts)
- ✅ Telemetry logs failure reasons (OpenTelemetry spans)
- ✅ UI shows progress (via Redis status polling)

## Troubleshooting

### Worker not consuming jobs

**Symptoms**: Jobs are enqueued but not being processed

```bash
# Check queue length
redis-cli LLEN wiretuner:export:pdf:queue

# Peek at first job without removing it
redis-cli LINDEX wiretuner:export:pdf:queue 0

# Check worker logs
docker-compose logs worker-export

# Verify Redis connectivity
redis-cli PING
```

**Common causes**:
- Worker not running (check `docker ps` or process list)
- Redis connection failure (check `REDIS_URL` environment variable)
- Worker crashed (check logs for panic or error messages)
- Semaphore exhausted (all worker slots busy with long-running jobs)

### Jobs stuck in processing

**Symptoms**: Job status remains "processing" indefinitely

```bash
# Check all status keys
redis-cli KEYS wiretuner:export:pdf:status:*

# Get specific job status
redis-cli GET wiretuner:export:pdf:status:{job_id}

# Check TTL (should be 24h = 86400s)
redis-cli TTL wiretuner:export:pdf:status:{job_id}

# View job details
redis-cli GET wiretuner:export:pdf:status:{job_id} | jq .
```

**Common causes**:
- Worker crashed during processing (job never marked complete/failed)
- Invalid output path (permission denied or disk full)
- SVG parsing hang (malformed SVG with infinite recursion)
- Memory exhaustion (OOM killer terminated worker)

**Resolution**:
1. Check worker logs for error messages
2. Manually update job status: `redis-cli SET wiretuner:export:pdf:status:{job_id} '{"status":"failed","error":"Worker timeout"}'`
3. Re-queue job with retry

### High memory usage

**Symptoms**: Worker using excessive RAM (>2GB per process)

```bash
# Monitor memory usage
docker stats worker-export

# Check SVG size distribution
redis-cli LINDEX wiretuner:export:pdf:queue 0 | jq '.svg_content | length'
```

**Solutions**:
- Reduce `WORKER_CONCURRENCY` (fewer concurrent jobs)
- Check for large SVG payloads (>10MB)
- Monitor rasterization dimensions (very large canvases use more memory)
- Limit SVG complexity (deep nesting, many paths)

### Connection errors

**Symptoms**: "Connection refused" or "Connection timeout" errors

```bash
# Test Redis connectivity
redis-cli -h redis ping

# Check network
docker network inspect wiretuner-network

# Verify Redis is listening
docker exec redis redis-cli ping
```

**Solutions**:
- Ensure Redis is running: `docker-compose up -d redis`
- Check `REDIS_URL` format: `redis://host:port/`
- Verify network configuration in docker-compose.yml
- Check firewall rules (if running on separate hosts)

### Performance issues

**Symptoms**: Slow export times, high CPU usage

```bash
# Check queue backlog
redis-cli LLEN wiretuner:export:pdf:queue

# Monitor worker performance
RUST_LOG=debug cargo run
```

**Optimization tips**:
- Increase `WORKER_CONCURRENCY` for I/O-bound workloads
- Use release build (`cargo build --release`)
- Profile with `cargo flamegraph` to identify bottlenecks
- Scale horizontally (run multiple worker instances)
- Consider SVG optimization (simplify paths, reduce nodes)

### Telemetry not working

**Symptoms**: No spans appearing in Jaeger UI

```bash
# Check Jaeger is running
curl http://localhost:16686

# Verify OTLP endpoint
docker-compose logs jaeger
```

**Solutions**:
- Ensure `OTEL_EXPORTER_OTLP_ENDPOINT` points to Jaeger
- Check Jaeger collector logs for errors
- Verify network connectivity between worker and Jaeger
- Test with `RUST_LOG=trace` to see telemetry initialization

## License

MIT
