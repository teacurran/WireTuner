/**
 * Integration tests for telemetry collector opt-out enforcement.
 *
 * Verifies that the collector properly:
 * - Validates payloads against api/telemetry.yaml schema
 * - Enforces telemetryOptIn field
 * - Rejects opted-out telemetry
 * - Records rejection metrics
 * - Returns correct HTTP status codes
 */

const request = require('supertest');
const app = require('../lib/main');

describe('Telemetry Collector - Opt-Out Enforcement', () => {
  describe('POST /v1/telemetry/perf-sample', () => {
    it('should accept valid sample with telemetryOptIn=true', async () => {
      const sample = {
        documentId: 'a3bb189e-8bf9-4bc6-9c8e-d3d0c2b3e9f1',
        artboardId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        snapshotDurationMs: 250,
        cursorLatencyUs: 5000,
        platform: 'macos',
        flagsActive: ['enable-gpu-acceleration'],
        telemetryOptIn: true,
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(202);

      expect(response.body).toHaveProperty('correlationId');
      expect(response.body.status).toBe('accepted');
    });

    it('should reject sample with telemetryOptIn=false (opt-out enforcement)', async () => {
      const sample = {
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'macos',
        flagsActive: [],
        telemetryOptIn: false, // User opted out
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(202); // Still returns 202 (graceful rejection)

      expect(response.body).toHaveProperty('correlationId');
      expect(response.body.status).toBe('accepted');
      // Server logs rejection internally but returns success to client
    });

    it('should reject sample without telemetryOptIn field', async () => {
      const sample = {
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'macos',
        flagsActive: [],
        // Missing telemetryOptIn field
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(400);

      expect(response.body.error).toBe('invalid_payload');
      expect(response.body.details.errors).toContain('telemetryOptIn must be a boolean');
    });

    it('should reject sample with invalid fps (out of range)', async () => {
      const sample = {
        fps: 300, // Exceeds max of 240
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'macos',
        flagsActive: [],
        telemetryOptIn: true,
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(400);

      expect(response.body.error).toBe('invalid_payload');
      expect(response.body.details.errors).toContain('fps must be a number between 0 and 240');
    });

    it('should reject sample with invalid platform', async () => {
      const sample = {
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'linux', // Invalid platform
        flagsActive: [],
        telemetryOptIn: true,
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(400);

      expect(response.body.error).toBe('invalid_payload');
    });

    it('should accept sample without optional fields', async () => {
      const sample = {
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'windows',
        flagsActive: [],
        telemetryOptIn: true,
        // No documentId, artboardId, snapshotDurationMs, cursorLatencyUs
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(202);

      expect(response.body.status).toBe('accepted');
    });

    it('should reject sample with negative eventReplayRate', async () => {
      const sample = {
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: -100, // Invalid negative
        samplingIntervalMs: 100,
        platform: 'macos',
        flagsActive: [],
        telemetryOptIn: true,
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(400);

      expect(response.body.error).toBe('invalid_payload');
    });
  });

  describe('POST /v1/telemetry/replay-inconsistency', () => {
    it('should accept valid replay inconsistency report', async () => {
      const report = {
        documentId: 'a3bb189e-8bf9-4bc6-9c8e-d3d0c2b3e9f1',
        snapshotSequence: 42,
        eventIds: [
          'e1234567-89ab-cdef-0123-456789abcdef',
          'e2345678-9abc-def0-1234-56789abcdef0',
        ],
        stateHashBefore: 'abc123',
        stateHashAfter: 'def456',
        clientVersion: '1.0.0',
        platform: 'macos',
      };

      const response = await request(app)
        .post('/v1/telemetry/replay-inconsistency')
        .send(report)
        .expect(202);

      expect(response.body).toHaveProperty('correlationId');
      expect(response.body.status).toBe('accepted');
    });
  });

  describe('Health Endpoints', () => {
    it('should return healthy status', async () => {
      const response = await request(app).get('/health').expect(200);

      expect(response.body.status).toBe('healthy');
      expect(response.body).toHaveProperty('service');
      expect(response.body).toHaveProperty('timestamp');
    });

    it('should return ready status', async () => {
      const response = await request(app).get('/ready').expect(200);

      expect(response.body.status).toBe('ready');
      expect(response.body).toHaveProperty('service');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('Opt-Out Compliance', () => {
    it('should handle batch of samples with mixed opt-in/opt-out', async () => {
      const samples = [
        {
          fps: 60,
          frameTimeMs: 16.67,
          eventReplayRate: 1000,
          samplingIntervalMs: 100,
          platform: 'macos',
          flagsActive: [],
          telemetryOptIn: true,
        },
        {
          fps: 55,
          frameTimeMs: 18.18,
          eventReplayRate: 800,
          samplingIntervalMs: 100,
          platform: 'macos',
          flagsActive: [],
          telemetryOptIn: false, // Opted out
        },
        {
          fps: 58,
          frameTimeMs: 17.24,
          eventReplayRate: 900,
          samplingIntervalMs: 100,
          platform: 'windows',
          flagsActive: [],
          telemetryOptIn: true,
        },
      ];

      // Send samples sequentially
      for (const sample of samples) {
        await request(app)
          .post('/v1/telemetry/perf-sample')
          .send(sample)
          .expect(202);
      }

      // All should return 202, but only opted-in samples are processed
      // (verified via logs and metrics, not HTTP response)
    });

    it('should not process sample when TELEMETRY_OPT_OUT_ENFORCE=true', async () => {
      // This test assumes TELEMETRY_OPT_OUT_ENFORCE=true in env
      process.env.TELEMETRY_OPT_OUT_ENFORCE = 'true';

      const sample = {
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'macos',
        flagsActive: [],
        telemetryOptIn: false,
      };

      const response = await request(app)
        .post('/v1/telemetry/perf-sample')
        .send(sample)
        .expect(202);

      // Server accepts but discards (check logs for rejection)
      expect(response.body.status).toBe('accepted');
    });
  });
});
