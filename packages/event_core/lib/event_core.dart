/// Event sourcing core infrastructure for WireTuner.
///
/// This package provides the fundamental event sourcing components:
/// - Event recorder with 50ms sampling for continuous actions
/// - Event replayer for rebuilding document state
/// - Snapshot manager for periodic state capture
/// - Event log management and persistence
///
/// ## Core Interfaces
///
/// - [EventRecorder]: Records user interaction events with automatic sampling
/// - [EventReplayer]: Replays events to reconstruct document state
/// - [SnapshotManager]: Manages periodic document state snapshots
///
/// ## Supporting Abstractions
///
/// - [EventSampler]: Sampling strategy for high-frequency events
/// - [EventDispatcher]: Asynchronous event routing to handlers
/// - [EventStoreGateway]: Persistence gateway for SQLite storage
/// - [MetricsSink]: Metrics collection for instrumentation
///
/// ## Default Implementations
///
/// - [DefaultEventRecorder]: Stub implementation with dependency injection
/// - [DefaultEventReplayer]: Stub implementation with dependency injection
/// - [DefaultSnapshotManager]: Stub implementation with dependency injection
///
/// ## Stub Implementations (for testing and development)
///
/// - [StubEventSampler]: In-memory event sampler
/// - [StubEventDispatcher]: In-memory event dispatcher
/// - [StubEventStoreGateway]: In-memory event store
/// - [StubMetricsSink]: Console-based metrics sink
library event_core;

// Core interfaces
export 'src/event_recorder.dart';
export 'src/event_replayer.dart';
export 'src/snapshot_manager.dart';

// Supporting abstractions
export 'src/event_sampler.dart';
export 'src/event_dispatcher.dart';
export 'src/event_store_gateway.dart';
export 'src/metrics_sink.dart';

// Stub implementations
export 'src/stubs/stub_event_sampler.dart';
export 'src/stubs/stub_event_dispatcher.dart';
export 'src/stubs/stub_event_store_gateway.dart';
export 'src/stubs/stub_metrics_sink.dart';
