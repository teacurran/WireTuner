/// Event schema exports and polymorphic deserialization utilities.
///
/// This file provides a consolidated export of all event types and
/// a factory method for polymorphic event deserialization from JSON.
library event_schema;

// Export all event types
export 'package:wiretuner/domain/events/event_base.dart';
export 'package:wiretuner/domain/events/path_events.dart';
export 'package:wiretuner/domain/events/object_events.dart';
export 'package:wiretuner/domain/events/style_events.dart';

import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/style_events.dart';

/// Deserializes an event from JSON using polymorphic dispatch.
///
/// The [json] map must contain an 'eventType' field that matches one of the
/// known event class names. This function dispatches to the appropriate
/// event class's fromJson constructor based on the eventType discriminator.
///
/// Throws [ArgumentError] if the eventType is missing or unknown.
///
/// Example:
/// ```dart
/// final json = {
///   'eventType': 'CreatePathEvent',
///   'eventId': 'evt_001',
///   'timestamp': 1699305600000,
///   'pathId': 'path_001',
///   'startAnchor': {'x': 100.0, 'y': 200.0},
/// };
/// final event = eventFromJson(json);
/// print(event.eventType); // 'CreatePathEvent'
/// ```
EventBase eventFromJson(Map<String, dynamic> json) {
  final eventType = json['eventType'];

  if (eventType == null) {
    throw ArgumentError('Missing eventType field in JSON');
  }

  switch (eventType) {
    // Path events
    case 'CreatePathEvent':
      return CreatePathEvent.fromJson(json);
    case 'AddAnchorEvent':
      return AddAnchorEvent.fromJson(json);
    case 'FinishPathEvent':
      return FinishPathEvent.fromJson(json);
    case 'ModifyAnchorEvent':
      return ModifyAnchorEvent.fromJson(json);

    // Object events
    case 'MoveObjectEvent':
      return MoveObjectEvent.fromJson(json);
    case 'CreateShapeEvent':
      return CreateShapeEvent.fromJson(json);

    // Style events
    case 'ModifyStyleEvent':
      return ModifyStyleEvent.fromJson(json);

    default:
      throw ArgumentError('Unknown eventType: $eventType');
  }
}
