/// WireTuner Collaboration Gateway Service
///
/// Real-time collaboration backend service implementing Operational Transform (OT)
/// for conflict-free concurrent editing.
///
/// **Responsibilities:**
/// - WebSocket server for real-time operation streaming
/// - OT transformation engine for concurrent edit resolution
/// - JWT authentication and session management
/// - Redis pub/sub for multi-instance scaling
/// - Presence tracking (cursors, selections, user status)
///
/// **Technology Stack:**
/// - Dart Frog for HTTP/WebSocket handling
/// - Redis for pub/sub event distribution
/// - JWT for authentication
/// - In-memory session management with persistence hooks
///
/// **Key Features:**
/// - Maximum 10 concurrent editors per document (ADR-0002)
/// - <100ms p99 latency for transform + broadcast
/// - Automatic idle timeout (5 minutes)
/// - Rate limiting (300 ops/minute per client)
/// - Graceful degradation and reconnection support
///
/// **Status:** MVP implementation completed in Iteration I4.
library collaboration_gateway;

export 'main.dart';
export 'gateway_server.dart';
export 'ot/operation_types.dart';
export 'ot/transformers.dart';
export 'models/session.dart';
export 'middleware/auth_middleware.dart';
export 'infra/redis_channel.dart';
