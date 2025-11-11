/// Event schema exports and polymorphic deserialization utilities.
///
/// This file provides a consolidated export of all event types and utilities
/// for working with the event sourcing system.
library event_schema;

export 'package:wiretuner/domain/events/event_base.dart';
export 'package:wiretuner/domain/events/path_events.dart';
export 'package:wiretuner/domain/events/object_events.dart';
export 'package:wiretuner/domain/events/style_events.dart';
export 'package:wiretuner/domain/events/selection_events.dart';
export 'package:wiretuner/domain/events/viewport_events.dart';
export 'package:wiretuner/domain/events/file_events.dart';

import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/style_events.dart';
import 'package:wiretuner/domain/events/selection_events.dart';
import 'package:wiretuner/domain/events/viewport_events.dart';
import 'package:wiretuner/domain/events/file_events.dart';

/// Factory function for polymorphic event deserialization.
///
/// Takes a JSON map containing an 'eventType' field and deserializes
/// it to the appropriate concrete event class.
///
/// Throws [ArgumentError] if the event type is unknown.
///
/// Example:
/// ```dart
/// final json = {
///   'eventType': 'CreatePathEvent',
///   'eventId': 'abc-123',
///   'timestamp': 1699305600000,
///   'pathId': 'path-1',
///   'startAnchor': {'x': 100.0, 'y': 200.0}
/// };
/// final event = eventFromJson(json);
/// // Returns CreatePathEvent instance
/// ```
EventBase eventFromJson(Map<String, dynamic> json) {
  final eventType = json['eventType'] as String?;

  if (eventType == null) {
    throw ArgumentError('Missing required field: eventType');
  }

  switch (eventType) {
    // Path Events
    case 'CreatePathEvent':
      return CreatePathEvent.fromJson(json);
    case 'AddAnchorEvent':
      return AddAnchorEvent.fromJson(json);
    case 'FinishPathEvent':
      return FinishPathEvent.fromJson(json);
    case 'ModifyAnchorEvent':
      return ModifyAnchorEvent.fromJson(json);

    // Object Events
    case 'MoveObjectEvent':
      return MoveObjectEvent.fromJson(json);
    case 'CreateShapeEvent':
      return CreateShapeEvent.fromJson(json);
    case 'DeleteObjectEvent':
      return DeleteObjectEvent.fromJson(json);

    // Style Events
    case 'ModifyStyleEvent':
      return ModifyStyleEvent.fromJson(json);

    // Selection Events
    case 'SelectObjectsEvent':
      return SelectObjectsEvent.fromJson(json);
    case 'DeselectObjectsEvent':
      return DeselectObjectsEvent.fromJson(json);
    case 'ClearSelectionEvent':
      return ClearSelectionEvent.fromJson(json);

    // Viewport Events
    case 'ViewportPanEvent':
      return ViewportPanEvent.fromJson(json);
    case 'ViewportZoomEvent':
      return ViewportZoomEvent.fromJson(json);
    case 'ViewportResetEvent':
      return ViewportResetEvent.fromJson(json);

    // File Events
    case 'SaveDocumentEvent':
      return SaveDocumentEvent.fromJson(json);
    case 'LoadDocumentEvent':
      return LoadDocumentEvent.fromJson(json);
    case 'DocumentLoadedEvent':
      return DocumentLoadedEvent.fromJson(json);

    default:
      throw ArgumentError('Unknown event type: $eventType');
  }
}

/// List of all valid event type names.
///
/// Useful for validation and documentation purposes.
const List<String> validEventTypes = [
  // Path Events
  'CreatePathEvent',
  'AddAnchorEvent',
  'FinishPathEvent',
  'ModifyAnchorEvent',

  // Object Events
  'MoveObjectEvent',
  'CreateShapeEvent',
  'DeleteObjectEvent',

  // Style Events
  'ModifyStyleEvent',

  // Selection Events
  'SelectObjectsEvent',
  'DeselectObjectsEvent',
  'ClearSelectionEvent',

  // Viewport Events
  'ViewportPanEvent',
  'ViewportZoomEvent',
  'ViewportResetEvent',

  // File Events
  'SaveDocumentEvent',
  'LoadDocumentEvent',
  'DocumentLoadedEvent',
];
