/**
 * WireTuner Telemetry Collector
 *
 * OpenTelemetry-compliant collector service that:
 * - Ingests OTLP payloads via REST endpoints (api/telemetry.yaml)
 * - Validates payloads against OpenAPI schema
 * - Exports metrics to Prometheus
 * - Forwards traces to OTLP backend
 * - Enforces opt-out compliance
 * - Provides health/readiness endpoints
 */

require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { createLogger, format, transports } = require('winston');

// OpenTelemetry imports
const { MeterProvider } = require('@opentelemetry/sdk-metrics');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

// Service configuration
const PORT = process.env.PORT || 3001;
const SERVICE_NAME = 'wiretuner-telemetry-collector';
const TELEMETRY_OPT_OUT_ENFORCE = process.env.TELEMETRY_OPT_OUT_ENFORCE !== 'false';

// Structured logger following Section 3.6 schema
const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json()
  ),
  defaultMeta: {
    component: 'TelemetryCollector',
    service: SERVICE_NAME,
  },
  transports: [
    new transports.Console(),
    // Add CloudWatch transport in production
  ],
});

// Initialize Prometheus exporter
const prometheusExporter = new PrometheusExporter(
  {
    port: process.env.PROMETHEUS_PORT || 9464,
  },
  () => {
    logger.info({
      message: `Prometheus metrics available at http://localhost:${prometheusExporter.port}${prometheusExporter.endpoint}`,
      eventType: 'PrometheusExporterStarted',
    });
  }
);

// Initialize OpenTelemetry Meter Provider
const meterProvider = new MeterProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
    [SemanticResourceAttributes.SERVICE_VERSION]: '0.1.0',
  }),
  readers: [prometheusExporter],
});

const meter = meterProvider.getMeter(SERVICE_NAME);

// Metrics catalog (Section 3.15)
const metrics = {
  samplesReceived: meter.createCounter('telemetry.samples.received', {
    description: 'Total performance samples received',
  }),
  samplesRejected: meter.createCounter('telemetry.samples.rejected', {
    description: 'Samples rejected due to validation/opt-out',
  }),
  optOutRatio: meter.createObservableGauge('telemetry.opt_out_ratio', {
    description: 'Ratio of samples with telemetry opt-out',
  }),
  ingestionLatency: meter.createHistogram('telemetry.ingestion.latency_ms', {
    description: 'Ingestion request latency in milliseconds',
  }),
};

// In-memory stats for opt-out ratio calculation
let totalSamples = 0;
let optedOutSamples = 0;

metrics.optOutRatio.addCallback((observableResult) => {
  const ratio = totalSamples > 0 ? optedOutSamples / totalSamples : 0;
  observableResult.observe(ratio);
});

// Express app
const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));

// Request logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  res.on('finish', () => {
    const latency = Date.now() - startTime;
    logger.info({
      eventType: 'HttpRequest',
      message: `${req.method} ${req.path} ${res.statusCode}`,
      latencyMs: latency,
      metadata: {
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        userAgent: req.get('user-agent'),
      },
    });
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: SERVICE_NAME,
    timestamp: new Date().toISOString(),
  });
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
  // Check if Prometheus exporter is ready
  const ready = prometheusExporter !== null;

  if (ready) {
    res.json({
      status: 'ready',
      service: SERVICE_NAME,
      timestamp: new Date().toISOString(),
    });
  } else {
    res.status(503).json({
      status: 'not ready',
      service: SERVICE_NAME,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * JWT authentication middleware (stub)
 *
 * In production, this should validate JWT tokens from the auth system.
 * For now, we'll accept any request for local development.
 */
function authenticateJWT(req, res, next) {
  const authHeader = req.headers.authorization;

  if (process.env.NODE_ENV === 'production' && !authHeader) {
    logger.warn({
      eventType: 'AuthenticationFailed',
      message: 'Missing Authorization header',
      metadata: { path: req.path },
    });

    return res.status(401).json({
      error: 'unauthorized',
      message: 'Missing or invalid JWT token',
    });
  }

  // TODO: Validate JWT token with jsonwebtoken
  // const token = authHeader?.split(' ')[1];
  // jwt.verify(token, process.env.JWT_SECRET, (err, user) => { ... });

  next();
}

/**
 * Validates performance sample payload against api/telemetry.yaml schema.
 */
function validatePerformanceSample(sample) {
  const errors = [];

  // Required fields
  if (typeof sample.fps !== 'number' || sample.fps < 0 || sample.fps > 240) {
    errors.push('fps must be a number between 0 and 240');
  }

  if (typeof sample.frameTimeMs !== 'number' || sample.frameTimeMs < 0) {
    errors.push('frameTimeMs must be a non-negative number');
  }

  if (typeof sample.eventReplayRate !== 'number' || sample.eventReplayRate < 0) {
    errors.push('eventReplayRate must be a non-negative number');
  }

  if (typeof sample.samplingIntervalMs !== 'number' || sample.samplingIntervalMs < 0) {
    errors.push('samplingIntervalMs must be a non-negative number');
  }

  if (!['macos', 'windows'].includes(sample.platform)) {
    errors.push('platform must be "macos" or "windows"');
  }

  if (typeof sample.telemetryOptIn !== 'boolean') {
    errors.push('telemetryOptIn must be a boolean');
  }

  return errors;
}

/**
 * POST /v1/telemetry/perf-sample
 *
 * Ingests performance telemetry sample from desktop clients.
 * Implements api/telemetry.yaml specification.
 */
app.post('/v1/telemetry/perf-sample', authenticateJWT, (req, res) => {
  const startTime = Date.now();
  const sample = req.body;

  try {
    // Validate payload
    const errors = validatePerformanceSample(sample);
    if (errors.length > 0) {
      metrics.samplesRejected.add(1, { reason: 'validation_failed' });

      logger.warn({
        eventType: 'ValidationFailed',
        message: 'Performance sample validation failed',
        metadata: { errors, sample },
      });

      return res.status(400).json({
        error: 'invalid_payload',
        message: 'Performance sample validation failed',
        details: { errors },
      });
    }

    // Enforce opt-out compliance
    if (TELEMETRY_OPT_OUT_ENFORCE && !sample.telemetryOptIn) {
      metrics.samplesRejected.add(1, { reason: 'opted_out' });
      optedOutSamples++;
      totalSamples++;

      logger.info({
        eventType: 'SampleRejected',
        message: 'Sample rejected: telemetry opt-out',
        metadata: { documentId: sample.documentId },
      });

      return res.status(202).json({
        correlationId: generateCorrelationId(),
        status: 'accepted',
      });
    }

    totalSamples++;

    // Record metrics to Prometheus
    metrics.samplesReceived.add(1, {
      platform: sample.platform,
    });

    const latency = Date.now() - startTime;
    metrics.ingestionLatency.record(latency, {
      platform: sample.platform,
    });

    // Log structured telemetry (for CloudWatch forwarding)
    logger.info({
      eventType: 'PerformanceSampleIngested',
      message: 'Performance sample ingested successfully',
      latencyMs: latency,
      documentId: sample.documentId,
      featureFlagContext: sample.flagsActive || [],
      metadata: {
        fps: sample.fps,
        frameTimeMs: sample.frameTimeMs,
        eventReplayRate: sample.eventReplayRate,
        platform: sample.platform,
        snapshotDurationMs: sample.snapshotDurationMs,
        cursorLatencyUs: sample.cursorLatencyUs,
      },
    });

    // Generate correlation ID
    const correlationId = generateCorrelationId();

    res.status(202).json({
      correlationId,
      status: 'accepted',
    });
  } catch (error) {
    metrics.samplesRejected.add(1, { reason: 'error' });

    logger.error({
      eventType: 'IngestionError',
      message: 'Failed to ingest performance sample',
      metadata: { error: error.message, stack: error.stack },
    });

    res.status(500).json({
      error: 'internal_error',
      message: 'Failed to process telemetry sample',
    });
  }
});

/**
 * POST /v1/telemetry/replay-inconsistency
 *
 * Reports event replay inconsistency for debugging non-deterministic replay.
 */
app.post('/v1/telemetry/replay-inconsistency', authenticateJWT, (req, res) => {
  const report = req.body;

  logger.warn({
    eventType: 'ReplayInconsistency',
    message: 'Event replay inconsistency detected',
    documentId: report.documentId,
    metadata: report,
  });

  res.status(202).json({
    correlationId: generateCorrelationId(),
    status: 'accepted',
  });
});

/**
 * Generates a correlation ID for tracking telemetry batches.
 */
function generateCorrelationId() {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Start server
const server = app.listen(PORT, () => {
  logger.info({
    eventType: 'ServiceStarted',
    message: `Telemetry collector listening on port ${PORT}`,
    metadata: {
      port: PORT,
      optOutEnforcement: TELEMETRY_OPT_OUT_ENFORCE,
      prometheusPort: prometheusExporter.port,
    },
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info({
    eventType: 'ServiceStopping',
    message: 'SIGTERM received, shutting down gracefully',
  });

  server.close(() => {
    logger.info({
      eventType: 'ServiceStopped',
      message: 'Server closed',
    });

    process.exit(0);
  });
});

module.exports = app; // Export for testing
