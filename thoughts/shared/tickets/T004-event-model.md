# T004: Event Model - Base Classes and Event Types

## Status
- **Phase**: 1 - Core Event System
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T003

## Overview
Implement the core Event model classes and type system. This establishes the foundation for all event sourcing functionality in WireTuner.

## Objectives
- Create base Event class
- Define all event type enums
- Implement event serialization/deserialization
- Create strongly-typed event subclasses
- Enable event validation

## Requirements

### Functional Requirements
1. Base Event class captures common fields (id, sequence, timestamp, user_id, type)
2. Event types are strongly typed (not just strings)
3. Events can be serialized to/from JSON
4. Event data is validated on creation
5. Events are immutable once created

### Technical Requirements
- Use Dart sealed classes for type safety
- JSON serialization with `json_serializable`
- Immutable data structures (final fields)
- Type-safe event data payloads

## Implementation Details

### Dependencies (pubspec.yaml)
```yaml
dependencies:
  json_annotation: ^4.8.1
  uuid: ^4.2.0

dev_dependencies:
  json_serializable: ^6.7.1
  build_runner: ^2.4.0
```

### Base Event Class (lib/models/events/event.dart)
```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final String id;
  final int sequence;
  final DateTime timestamp;
  final String userId;
  final EventType type;
  final Map<String, dynamic> data;

  Event({
    String? id,
    required this.sequence,
    DateTime? timestamp,
    required this.userId,
    required this.type,
    required this.data,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  @override
  String toString() => 'Event($type @ $sequence)';
}
```

### Event Type Enum (lib/models/events/event_type.dart)
```dart
enum EventType {
  // Document events
  documentCreated('document.created'),
  documentMetadataChanged('document.metadata_changed'),

  // Object creation events
  objectPathCreated('object.path.created'),
  objectShapeCreated('object.shape.created'),
  objectImported('object.imported'),

  // Object modification events
  objectTransformed('object.transformed'),
  objectStyled('object.styled'),
  objectDeleted('object.deleted'),
  objectDuplicated('object.duplicated'),

  // Path editing events
  pathAnchorAdded('path.anchor.added'),
  pathAnchorMoved('path.anchor.moved'),
  pathAnchorDeleted('path.anchor.deleted'),
  pathBcpAdjusted('path.bcp.adjusted'),
  pathSegmentTypeChanged('path.segment.type_changed'),

  // Selection events
  selectionChanged('selection.changed'),
  selectionCleared('selection.cleared'),

  // Viewport events
  viewportPanned('viewport.panned'),
  viewportZoomed('viewport.zoomed'),

  // Interaction events (sampled)
  interactionDrag('interaction.drag'),
  interactionDraw('interaction.draw');

  const EventType(this.value);
  final String value;

  static EventType fromString(String value) {
    return EventType.values.firstWhere((e) => e.value == value);
  }
}
```

### Strongly-Typed Event Subclasses

**Path Anchor Moved Event** (lib/models/events/path_anchor_moved_event.dart)
```dart
import 'package:flutter/material.dart';
import 'event.dart';

class PathAnchorMovedEvent {
  final String objectId;
  final int anchorIndex;
  final Offset oldPosition;
  final Offset newPosition;

  PathAnchorMovedEvent({
    required this.objectId,
    required this.anchorIndex,
    required this.oldPosition,
    required this.newPosition,
  });

  Event toEvent({
    required int sequence,
    required String userId,
  }) {
    return Event(
      sequence: sequence,
      userId: userId,
      type: EventType.pathAnchorMoved,
      data: {
        'objectId': objectId,
        'anchorIndex': anchorIndex,
        'oldPosition': {'x': oldPosition.dx, 'y': oldPosition.dy},
        'newPosition': {'x': newPosition.dx, 'y': newPosition.dy},
      },
    );
  }

  factory PathAnchorMovedEvent.fromEvent(Event event) {
    assert(event.type == EventType.pathAnchorMoved);
    return PathAnchorMovedEvent(
      objectId: event.data['objectId'] as String,
      anchorIndex: event.data['anchorIndex'] as int,
      oldPosition: Offset(
        event.data['oldPosition']['x'] as double,
        event.data['oldPosition']['y'] as double,
      ),
      newPosition: Offset(
        event.data['newPosition']['x'] as double,
        event.data['newPosition']['y'] as double,
      ),
    );
  }
}
```

**Object Shape Created Event** (lib/models/events/object_shape_created_event.dart)
```dart
import 'package:flutter/material.dart';
import 'event.dart';

enum ShapeType {
  rectangle,
  ellipse,
  polygon,
  star,
}

class ObjectShapeCreatedEvent {
  final String objectId;
  final ShapeType shapeType;
  final Rect bounds;
  final Map<String, dynamic>? properties; // sides for polygon, points for star, etc.

  ObjectShapeCreatedEvent({
    required this.objectId,
    required this.shapeType,
    required this.bounds,
    this.properties,
  });

  Event toEvent({
    required int sequence,
    required String userId,
  }) {
    return Event(
      sequence: sequence,
      userId: userId,
      type: EventType.objectShapeCreated,
      data: {
        'objectId': objectId,
        'shapeType': shapeType.name,
        'bounds': {
          'left': bounds.left,
          'top': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        },
        if (properties != null) 'properties': properties,
      },
    );
  }

  factory ObjectShapeCreatedEvent.fromEvent(Event event) {
    assert(event.type == EventType.objectShapeCreated);
    final boundsData = event.data['bounds'];
    return ObjectShapeCreatedEvent(
      objectId: event.data['objectId'] as String,
      shapeType: ShapeType.values.byName(event.data['shapeType'] as String),
      bounds: Rect.fromLTWH(
        boundsData['left'] as double,
        boundsData['top'] as double,
        boundsData['width'] as double,
        boundsData['height'] as double,
      ),
      properties: event.data['properties'] as Map<String, dynamic>?,
    );
  }
}
```

**Selection Changed Event** (lib/models/events/selection_changed_event.dart)
```dart
import 'event.dart';

class SelectionChangedEvent {
  final List<String> selectedObjectIds;
  final List<String> previouslySelectedObjectIds;

  SelectionChangedEvent({
    required this.selectedObjectIds,
    required this.previouslySelectedObjectIds,
  });

  Event toEvent({
    required int sequence,
    required String userId,
  }) {
    return Event(
      sequence: sequence,
      userId: userId,
      type: EventType.selectionChanged,
      data: {
        'selectedObjectIds': selectedObjectIds,
        'previouslySelectedObjectIds': previouslySelectedObjectIds,
      },
    );
  }

  factory SelectionChangedEvent.fromEvent(Event event) {
    assert(event.type == EventType.selectionChanged);
    return SelectionChangedEvent(
      selectedObjectIds: List<String>.from(event.data['selectedObjectIds']),
      previouslySelectedObjectIds:
          List<String>.from(event.data['previouslySelectedObjectIds']),
    );
  }
}
```

**Interaction Drag Event** (lib/models/events/interaction_drag_event.dart)
```dart
import 'package:flutter/material.dart';
import 'event.dart';

class InteractionDragEvent {
  final String interactionId; // Unique ID for this drag session
  final List<Offset> sampledPath; // Sampled mouse positions
  final DateTime startTime;
  final DateTime endTime;

  InteractionDragEvent({
    required this.interactionId,
    required this.sampledPath,
    required this.startTime,
    required this.endTime,
  });

  Event toEvent({
    required int sequence,
    required String userId,
  }) {
    return Event(
      sequence: sequence,
      userId: userId,
      type: EventType.interactionDrag,
      data: {
        'interactionId': interactionId,
        'sampledPath': sampledPath
            .map((offset) => {'x': offset.dx, 'y': offset.dy})
            .toList(),
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      },
    );
  }

  factory InteractionDragEvent.fromEvent(Event event) {
    assert(event.type == EventType.interactionDrag);
    return InteractionDragEvent(
      interactionId: event.data['interactionId'] as String,
      sampledPath: (event.data['sampledPath'] as List)
          .map((p) => Offset(p['x'] as double, p['y'] as double))
          .toList(),
      startTime: DateTime.parse(event.data['startTime'] as String),
      endTime: DateTime.parse(event.data['endTime'] as String),
    );
  }
}
```

## Success Criteria

### Automated Verification
- [ ] Code generation runs successfully: `flutter pub run build_runner build`
- [ ] All event types compile without errors
- [ ] Unit tests pass:
  - [ ] Event can be created with all required fields
  - [ ] Event can be serialized to JSON
  - [ ] Event can be deserialized from JSON
  - [ ] Event roundtrip (to JSON and back) preserves data
  - [ ] Strongly-typed events convert to/from base Event correctly
  - [ ] Event validation catches invalid data

### Manual Verification
- [ ] Can create each event type
- [ ] JSON output is readable and contains expected fields
- [ ] Timestamps are in ISO 8601 format
- [ ] UUIDs are valid v4 format
- [ ] Event type strings match design document

## Testing Strategy

### Unit Tests (test/models/events/event_test.dart)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/models/events/event.dart';
import 'package:wiretuner/models/events/path_anchor_moved_event.dart';

void main() {
  group('Event', () {
    test('can be created with required fields', () {
      final event = Event(
        sequence: 1,
        userId: 'user_123',
        type: EventType.pathAnchorMoved,
        data: {'test': 'data'},
      );

      expect(event.sequence, 1);
      expect(event.userId, 'user_123');
      expect(event.type, EventType.pathAnchorMoved);
      expect(event.id, isNotEmpty);
      expect(event.timestamp, isNotNull);
    });

    test('can be serialized to JSON', () {
      final event = Event(
        sequence: 1,
        userId: 'user_123',
        type: EventType.pathAnchorMoved,
        data: {'test': 'data'},
      );

      final json = event.toJson();

      expect(json['sequence'], 1);
      expect(json['userId'], 'user_123');
      expect(json['type'], 'path.anchor.moved');
      expect(json['data'], {'test': 'data'});
    });

    test('can be deserialized from JSON', () {
      final json = {
        'id': 'test-id',
        'sequence': 1,
        'timestamp': '2025-11-05T10:00:00.000Z',
        'userId': 'user_123',
        'type': 'path.anchor.moved',
        'data': {'test': 'data'},
      };

      final event = Event.fromJson(json);

      expect(event.id, 'test-id');
      expect(event.sequence, 1);
      expect(event.userId, 'user_123');
      expect(event.type, EventType.pathAnchorMoved);
    });
  });

  group('PathAnchorMovedEvent', () {
    test('converts to Event correctly', () {
      final typedEvent = PathAnchorMovedEvent(
        objectId: 'path_1',
        anchorIndex: 2,
        oldPosition: const Offset(10, 20),
        newPosition: const Offset(15, 25),
      );

      final event = typedEvent.toEvent(sequence: 1, userId: 'user_123');

      expect(event.type, EventType.pathAnchorMoved);
      expect(event.data['objectId'], 'path_1');
      expect(event.data['anchorIndex'], 2);
      expect(event.data['oldPosition']['x'], 10);
      expect(event.data['newPosition']['y'], 25);
    });

    test('converts from Event correctly', () {
      final event = Event(
        sequence: 1,
        userId: 'user_123',
        type: EventType.pathAnchorMoved,
        data: {
          'objectId': 'path_1',
          'anchorIndex': 2,
          'oldPosition': {'x': 10.0, 'y': 20.0},
          'newPosition': {'x': 15.0, 'y': 25.0},
        },
      );

      final typedEvent = PathAnchorMovedEvent.fromEvent(event);

      expect(typedEvent.objectId, 'path_1');
      expect(typedEvent.anchorIndex, 2);
      expect(typedEvent.oldPosition, const Offset(10, 20));
      expect(typedEvent.newPosition, const Offset(15, 25));
    });
  });
}
```

## Notes
- Additional strongly-typed event classes will be added as needed
- Consider using code generation for event subclasses if pattern becomes repetitive
- Event validation should be lightweight (don't block UI thread)
- Consider adding event schema version field for future compatibility

## References
- Design Document: `/Users/tea/dev/github/wiretuner/thoughts/shared/tickets/T003-event-sourcing-architecture-design.md`
- json_serializable: https://pub.dev/packages/json_serializable
