/// WireTuner Infrastructure Package (Infrastructure Layer)
///
/// This package contains the Infrastructure layer of the WireTuner application
/// following Clean Architecture principles.
///
/// **Responsibilities:**
/// - SQLite event store implementation
/// - File I/O operations (.wiretuner file format)
/// - SVG import/export services
/// - AI (Adobe Illustrator) import services
/// - PDF export services
/// - Event persistence and snapshot management
/// - Collaboration client for real-time editing
///
/// **Dependencies:**
/// - Depends on `core` for domain models and event definitions
/// - External I/O libraries: sqflite, path_provider, xml, pdf
/// - WebSocket for collaboration
///
/// **Architecture Layer:** Infrastructure
library infrastructure;

export 'collaboration/collaboration_client.dart';
export 'import/ai_importer.dart';
