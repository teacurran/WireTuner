# WireTuner Telemetry Collector

OpenTelemetry-compliant collector service for ingesting, validating, and forwarding telemetry data from WireTuner desktop clients.

## Features

- **OTLP Ingestion**: REST endpoints following `api/telemetry.yaml` specification
- **Schema Validation**: Validates payloads against OpenAPI schema
- **Opt-out Enforcement**: Respects user privacy by rejecting opted-out telemetry
- **Prometheus Export**: Exposes metrics for monitoring and alerting
- **Structured Logging**: JSON logs aligned with Section 3.6 schema
- **Health/Readiness**: Kubernetes-compatible health checks

## Quick Start

### Installation

```bash
npm install
```

### Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

### Development

```bash
npm run dev
```

### Production

```bash
npm start
```

## Endpoints

### Telemetry Ingestion

#### POST /v1/telemetry/perf-sample

Ingests performance telemetry samples from desktop clients.

**Request:**
```json
{
  "documentId": "a3bb189e-8bf9-4bc6-9c8e-d3d0c2b3e9f1",
  "artboardId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "fps": 60,
  "frameTimeMs": 16.67,
  "eventReplayRate": 1000,
  "samplingIntervalMs": 100,
  "snapshotDurationMs": 250,
  "cursorLatencyUs": 5000,
  "platform": "macos",
  "flagsActive": ["enable-gpu-acceleration"],
  "telemetryOptIn": true
}
```

**Response (202 Accepted):**
```json
{
  "correlationId": "1699564821234-x7k9m2p",
  "status": "accepted"
}
```

#### POST /v1/telemetry/replay-inconsistency

Reports event replay inconsistencies for debugging.

### Health Checks

#### GET /health

Returns service health status.

#### GET /ready

Returns service readiness status.

## Metrics

Prometheus metrics are exposed on port 9464 (configurable via `PROMETHEUS_PORT`):

```bash
curl http://localhost:9464/metrics
```

### Available Metrics

- `telemetry.samples.received` - Total performance samples received
- `telemetry.samples.rejected` - Samples rejected (validation/opt-out)
- `telemetry.opt_out_ratio` - Ratio of samples with opt-out
- `telemetry.ingestion.latency_ms` - Ingestion latency histogram

## Opt-out Enforcement

The collector enforces telemetry opt-out by default (`TELEMETRY_OPT_OUT_ENFORCE=true`):

1. Validates `telemetryOptIn` field in each payload
2. Rejects samples when `telemetryOptIn=false`
3. Returns 202 Accepted (no error to client)
4. Logs rejection event
5. Increments `telemetry.samples.rejected{reason="opted_out"}` metric

This ensures user privacy and compliance with telemetry policies.

## Authentication

In production, the collector validates JWT tokens:

```bash
# Set JWT secret
JWT_SECRET=your-secret-key-here
```

Clients must include JWT in Authorization header:

```
Authorization: Bearer <jwt-token>
```

## Testing

```bash
npm test
```

## Deployment

### Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3001 9464
CMD ["npm", "start"]
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telemetry-collector
spec:
  replicas: 3
  selector:
    matchLabels:
      app: telemetry-collector
  template:
    metadata:
      labels:
        app: telemetry-collector
    spec:
      containers:
      - name: collector
        image: wiretuner/telemetry-collector:0.1.0
        ports:
        - containerPort: 3001
          name: http
        - containerPort: 9464
          name: prometheus
        env:
        - name: NODE_ENV
          value: production
        - name: TELEMETRY_OPT_OUT_ENFORCE
          value: "true"
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
        readinessProbe:
          httpGet:
            path: /ready
            port: 3001
```

## Architecture

```
Desktop Client
    |
    | HTTPS (JWT auth)
    v
Telemetry Collector
    |
    +-> Prometheus (metrics)
    +-> CloudWatch Logs (structured logs)
    +-> OTLP Backend (optional forwarding)
```

## Compliance

The collector implements telemetry policies per `docs/qa/telemetry_policy.md`:

- ✅ Opt-out enforcement
- ✅ No PII collection
- ✅ 30-day retention window
- ✅ Audit trail logging
- ✅ Schema validation

## License

Proprietary - WireTuner Team
