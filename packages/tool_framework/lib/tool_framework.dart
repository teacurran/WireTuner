/// Tool telemetry and undo boundary annotation system.
///
/// This library provides:
/// - [ToolTelemetry]: Telemetry tracking and undo grouping for tools
/// - Human-readable undo label management for UI surfaces
/// - Tool usage metrics aggregation
/// - Integration with event sourcing flush operations
///
/// See also:
/// - [Event Schema Reference](../../docs/reference/event_schema.md)
/// - [Undo Label Reference](../../docs/reference/undo_labels.md)
library tool_framework;

export 'src/tool_telemetry.dart';
