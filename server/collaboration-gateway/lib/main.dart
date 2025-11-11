/// WireTuner Collaboration Gateway - Main Entry Point
///
/// This service provides real-time collaboration capabilities via WebSocket
/// connections with Operational Transform (OT) for conflict resolution.
///
/// **Key Features:**
/// - WebSocket server for real-time operation streaming
/// - OT transformation engine for concurrent edit conflict resolution
/// - JWT authentication and session management
/// - Redis pub/sub for multi-instance scaling
/// - GraphQL presence subscription fallback
/// - Rate limiting and idle timeout enforcement
///
/// **Architecture:**
/// - Dart Frog framework for HTTP/WebSocket handling
/// - Redis for pub/sub event distribution
/// - In-memory session management with persistence hooks
///
/// **Concurrency:**
/// - Maximum 10 concurrent editors per document (ADR-0002)
/// - P99 latency target: <100ms for transform + broadcast
///
/// **Security:**
/// - JWT token validation on connection
/// - Per-document access control
/// - Rate limiting (300 ops/minute per client)
library main;

export 'gateway_server.dart';
export 'ot/operation_types.dart';
export 'ot/transformers.dart';
export 'models/session.dart';
export 'middleware/auth_middleware.dart';
export 'infra/redis_channel.dart';
