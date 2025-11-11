import 'dart:io';

import 'package:io_services/io_services.dart' as io;
import 'package:logger/logger.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/import_export/import_validator.dart';

/// Service for importing Adobe Illustrator (.ai) files into WireTuner.
///
/// **DEPRECATED: This class is a legacy wrapper.**
/// New code should use `io_services.AIImporter` directly.
///
/// This wrapper delegates to the new implementation in the `io_services` package
/// while maintaining backward compatibility with existing code.
///
/// Adobe Illustrator files are PDF-based with proprietary extensions.
/// This importer extracts basic geometric data from the PDF layer,
/// ignoring Illustrator-specific features.
///
/// ## Migration Path
///
/// Old code:
/// ```dart
/// import 'package:wiretuner/infrastructure/import_export/ai_importer.dart';
/// final importer = AiImporter();
/// final events = await importer.importFromFile('/path/to/file.ai');
/// ```
///
/// New code:
/// ```dart
/// import 'package:io_services/io_services.dart';
/// final importer = AIImporter();
/// final result = await importer.importFromFile('/path/to/file.ai');
/// final events = result.events; // Now returns structured result with warnings
/// ```
///
/// ## Documentation
///
/// See `packages/io_services/lib/src/importers/ai_importer.dart` for full documentation.
/// See `docs/reference/ai_import_matrix.md` for feature coverage matrix.
@Deprecated(
  'Use io_services.AIImporter instead. '
  'This legacy wrapper will be removed in a future version.',
)
class AiImporter {
  final Logger _logger = Logger();

  /// Delegate to the new io_services implementation.
  late final io.AIImporter _delegate = io.AIImporter(logger: _logger);

  /// Imports an Adobe Illustrator file and returns a list of events.
  ///
  /// **DEPRECATED:** This method is a legacy wrapper that delegates to the new
  /// implementation in `io_services.AIImporter`.
  ///
  /// The returned events can be replayed via the event dispatcher
  /// to reconstruct the document.
  ///
  /// Parameters:
  /// - [filePath]: Absolute path to the .ai file
  ///
  /// Returns:
  /// - List of events representing the imported content (as raw Map objects)
  ///
  /// Throws:
  /// - [ImportException] if file is invalid or parsing fails
  ///
  /// Example:
  /// ```dart
  /// final importer = AiImporter();
  /// try {
  ///   final events = await importer.importFromFile('/path/to/file.ai');
  ///   print('Imported ${events.length} events');
  /// } catch (e) {
  ///   print('Import failed: $e');
  /// }
  /// ```
  @Deprecated('Use io_services.AIImporter instead')
  Future<List<EventBase>> importFromFile(String filePath) async {
    _logger.w(
      'Using deprecated AiImporter. '
      'Migrate to io_services.AIImporter for better error reporting and warnings.',
    );

    // Validate file using existing validator
    await ImportValidator.validateFile(filePath);

    try {
      // Delegate to new implementation
      final result = await _delegate.importFromFile(filePath);

      // Log warnings from new implementation
      for (final warning in result.warnings) {
        switch (warning.severity) {
          case 'info':
            _logger.i(warning.toString());
            break;
          case 'warning':
            _logger.w(warning.toString());
            break;
          case 'error':
            _logger.e(warning.toString());
            break;
        }
      }

      // Convert Map events back to EventBase for backward compatibility
      // Note: This is a placeholder conversion - production code would need
      // proper deserialization logic
      return _convertMapEventsToEventBase(result.events);
    } on io.AIImportException catch (e) {
      throw ImportException(e.message);
    } catch (e) {
      throw ImportException('Failed to parse AI file: $e');
    }
  }

  /// Converts Map-based events to EventBase instances.
  ///
  /// This is a placeholder for backward compatibility. In production,
  /// this would use proper event deserialization.
  List<EventBase> _convertMapEventsToEventBase(
    List<Map<String, dynamic>> mapEvents,
  ) {
    final events = <EventBase>[];

    for (final mapEvent in mapEvents) {
      final eventType = mapEvent['eventType'] as String;

      switch (eventType) {
        case 'CreatePathEvent':
          final startAnchor = mapEvent['startAnchor'] as Map<String, dynamic>;
          events.add(CreatePathEvent(
            eventId: mapEvent['eventId'] as String,
            timestamp: mapEvent['timestamp'] as int,
            pathId: mapEvent['pathId'] as String,
            startAnchor: Point(
              x: startAnchor['x'] as double,
              y: startAnchor['y'] as double,
            ),
            strokeColor: mapEvent['strokeColor'] as String?,
            strokeWidth: mapEvent['strokeWidth'] as double?,
            fillColor: mapEvent['fillColor'] as String?,
            opacity: mapEvent['opacity'] as double?,
          ));
          break;

        case 'AddAnchorEvent':
          final position = mapEvent['position'] as Map<String, dynamic>;
          final handleIn = mapEvent['handleIn'] as Map<String, dynamic>?;
          final handleOut = mapEvent['handleOut'] as Map<String, dynamic>?;

          events.add(AddAnchorEvent(
            eventId: mapEvent['eventId'] as String,
            timestamp: mapEvent['timestamp'] as int,
            pathId: mapEvent['pathId'] as String,
            position: Point(
              x: position['x'] as double,
              y: position['y'] as double,
            ),
            anchorType: _parseAnchorType(mapEvent['anchorType'] as String?),
            handleIn: handleIn != null
                ? Point(
                    x: handleIn['x'] as double,
                    y: handleIn['y'] as double,
                  )
                : null,
            handleOut: handleOut != null
                ? Point(
                    x: handleOut['x'] as double,
                    y: handleOut['y'] as double,
                  )
                : null,
          ));
          break;

        case 'FinishPathEvent':
          events.add(FinishPathEvent(
            eventId: mapEvent['eventId'] as String,
            timestamp: mapEvent['timestamp'] as int,
            pathId: mapEvent['pathId'] as String,
            closed: mapEvent['closed'] as bool? ?? false,
          ));
          break;

        default:
          _logger.w('Unknown event type during conversion: $eventType');
      }
    }

    return events;
  }

  /// Parses anchor type string to enum.
  AnchorType _parseAnchorType(String? type) {
    switch (type) {
      case 'bezier':
        return AnchorType.bezier;
      case 'line':
      default:
        return AnchorType.line;
    }
  }
}
