/// SQLite persistence gateway for WireTuner event sourcing.
///
/// This package provides:
/// - Connection factory with pooling for multi-document/multi-window scenarios
/// - Database configuration for file-based and in-memory databases
/// - Migration runner for schema management
/// - SQLite implementation of EventStoreGateway interface
///
/// Example usage:
/// ```dart
/// import 'package:io_services/io_services.dart';
///
/// // Initialize the connection factory
/// final factory = ConnectionFactory();
/// await factory.initialize();
///
/// // Open a database connection
/// final db = await factory.openConnection(
///   documentId: 'my-document',
///   config: DatabaseConfig.file(filePath: 'my_document.wiretuner'),
/// );
///
/// // Create an event gateway
/// final gateway = SqliteEventGateway(
///   db: db,
///   documentId: 'my-document',
/// );
///
/// // Persist events
/// await gateway.persistEvent({
///   'eventId': '123',
///   'eventType': 'CreatePath',
///   'timestamp': DateTime.now().millisecondsSinceEpoch,
///   'sequenceNumber': 0,
///   // ... other event data
/// });
///
/// // Close connection when done
/// await factory.closeConnection('my-document');
/// ```
library io_services;

export 'src/database_config.dart';
export 'src/gateway/connection_factory.dart';
export 'src/gateway/sqlite_event_gateway.dart';
export 'src/migrations/migration_runner.dart';
export 'src/save_service.dart';
