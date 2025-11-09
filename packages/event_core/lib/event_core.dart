/// Event sourcing core infrastructure for WireTuner.
///
/// This package provides the fundamental event sourcing components:
/// - Event recorder with 50ms sampling for continuous actions
/// - Event replayer for rebuilding document state
/// - Snapshot service for periodic state capture
/// - Event log management and persistence
library event_core;

export 'src/event_recorder.dart';
export 'src/event_replayer.dart';
export 'src/snapshot_service.dart';
