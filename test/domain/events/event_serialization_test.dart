import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/style_events.dart';
import 'package:wiretuner/api/event_schema.dart' as event_schema;

void main() {
  group('EventBase common fields', () {
    test('Point serializes and deserializes correctly', () {
      const point = Point(x: 123.45, y: 678.90);
      final json = point.toJson();
      final deserialized = Point.fromJson(json);

      expect(deserialized.x, equals(point.x));
      expect(deserialized.y, equals(point.y));
      expect(deserialized, equals(point));
    });
  });

  group('CreatePathEvent', () {
    test('serializes and deserializes correctly with all fields', () {
      const event = CreatePathEvent(
        eventId: 'evt_001',
        timestamp: 1699305600000,
        pathId: 'path_001',
        startAnchor: Point(x: 100.0, y: 200.0),
        fillColor: '#FF5733',
        strokeColor: '#000000',
        strokeWidth: 2.0,
        opacity: 1.0,
      );

      final json = event.toJson();
      final deserialized = CreatePathEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.pathId, equals(event.pathId));
      expect(deserialized.startAnchor, equals(event.startAnchor));
      expect(deserialized.fillColor, equals(event.fillColor));
      expect(deserialized.strokeColor, equals(event.strokeColor));
      expect(deserialized.strokeWidth, equals(event.strokeWidth));
      expect(deserialized.opacity, equals(event.opacity));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with minimal fields', () {
      const event = CreatePathEvent(
        eventId: 'evt_002',
        timestamp: 1699305601000,
        pathId: 'path_002',
        startAnchor: Point(x: 50.0, y: 75.0),
      );

      final json = event.toJson();
      final deserialized = CreatePathEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.pathId, equals(event.pathId));
      expect(deserialized.startAnchor, equals(event.startAnchor));
      expect(deserialized.fillColor, isNull);
      expect(deserialized.strokeColor, isNull);
      expect(deserialized.strokeWidth, isNull);
      expect(deserialized.opacity, isNull);
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = CreatePathEvent(
        eventId: 'evt_003',
        timestamp: 1699305602000,
        pathId: 'path_003',
        startAnchor: Point(x: 0.0, y: 0.0),
      );

      expect(event.eventType, equals('CreatePathEvent'));
    });
  });

  group('AddAnchorEvent', () {
    test('serializes and deserializes correctly with Bezier handles', () {
      const event = AddAnchorEvent(
        eventId: 'evt_004',
        timestamp: 1699305603000,
        pathId: 'path_001',
        position: Point(x: 150.0, y: 250.0),
        anchorType: AnchorType.bezier,
        handleIn: Point(x: 140.0, y: 240.0),
        handleOut: Point(x: 160.0, y: 260.0),
      );

      final json = event.toJson();
      final deserialized = AddAnchorEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.pathId, equals(event.pathId));
      expect(deserialized.position, equals(event.position));
      expect(deserialized.anchorType, equals(event.anchorType));
      expect(deserialized.handleIn, equals(event.handleIn));
      expect(deserialized.handleOut, equals(event.handleOut));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with line anchor type', () {
      const event = AddAnchorEvent(
        eventId: 'evt_005',
        timestamp: 1699305604000,
        pathId: 'path_001',
        position: Point(x: 200.0, y: 300.0),
      );

      final json = event.toJson();
      final deserialized = AddAnchorEvent.fromJson(json);

      expect(deserialized.anchorType, equals(AnchorType.line));
      expect(deserialized.handleIn, isNull);
      expect(deserialized.handleOut, isNull);
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = AddAnchorEvent(
        eventId: 'evt_006',
        timestamp: 1699305605000,
        pathId: 'path_001',
        position: Point(x: 0.0, y: 0.0),
      );

      expect(event.eventType, equals('AddAnchorEvent'));
    });
  });

  group('FinishPathEvent', () {
    test('serializes and deserializes correctly with closed path', () {
      const event = FinishPathEvent(
        eventId: 'evt_007',
        timestamp: 1699305606000,
        pathId: 'path_001',
        closed: true,
      );

      final json = event.toJson();
      final deserialized = FinishPathEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.pathId, equals(event.pathId));
      expect(deserialized.closed, equals(true));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with open path', () {
      const event = FinishPathEvent(
        eventId: 'evt_008',
        timestamp: 1699305607000,
        pathId: 'path_002',
      );

      final json = event.toJson();
      final deserialized = FinishPathEvent.fromJson(json);

      expect(deserialized.closed, equals(false));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = FinishPathEvent(
        eventId: 'evt_009',
        timestamp: 1699305608000,
        pathId: 'path_001',
      );

      expect(event.eventType, equals('FinishPathEvent'));
    });
  });

  group('ModifyAnchorEvent', () {
    test('serializes and deserializes correctly with all modifications', () {
      const event = ModifyAnchorEvent(
        eventId: 'evt_010',
        timestamp: 1699305609000,
        pathId: 'path_001',
        anchorIndex: 1,
        position: Point(x: 155.0, y: 255.0),
        handleIn: Point(x: 145.0, y: 245.0),
        handleOut: Point(x: 165.0, y: 265.0),
        anchorType: AnchorType.bezier,
      );

      final json = event.toJson();
      final deserialized = ModifyAnchorEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.pathId, equals(event.pathId));
      expect(deserialized.anchorIndex, equals(event.anchorIndex));
      expect(deserialized.position, equals(event.position));
      expect(deserialized.handleIn, equals(event.handleIn));
      expect(deserialized.handleOut, equals(event.handleOut));
      expect(deserialized.anchorType, equals(event.anchorType));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with partial modifications', () {
      const event = ModifyAnchorEvent(
        eventId: 'evt_011',
        timestamp: 1699305610000,
        pathId: 'path_001',
        anchorIndex: 2,
        position: Point(x: 180.0, y: 220.0),
      );

      final json = event.toJson();
      final deserialized = ModifyAnchorEvent.fromJson(json);

      expect(deserialized.position, equals(event.position));
      expect(deserialized.handleIn, isNull);
      expect(deserialized.handleOut, isNull);
      expect(deserialized.anchorType, isNull);
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = ModifyAnchorEvent(
        eventId: 'evt_012',
        timestamp: 1699305611000,
        pathId: 'path_001',
        anchorIndex: 0,
      );

      expect(event.eventType, equals('ModifyAnchorEvent'));
    });
  });

  group('MoveObjectEvent', () {
    test('serializes and deserializes correctly with single object', () {
      const event = MoveObjectEvent(
        eventId: 'evt_013',
        timestamp: 1699305612000,
        objectIds: ['path_001'],
        delta: Point(x: 10.0, y: -5.0),
      );

      final json = event.toJson();
      final deserialized = MoveObjectEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.objectIds, equals(event.objectIds));
      expect(deserialized.delta, equals(event.delta));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with multiple objects', () {
      const event = MoveObjectEvent(
        eventId: 'evt_014',
        timestamp: 1699305613000,
        objectIds: ['path_001', 'shape_002', 'path_003'],
        delta: Point(x: 20.0, y: 30.0),
      );

      final json = event.toJson();
      final deserialized = MoveObjectEvent.fromJson(json);

      expect(deserialized.objectIds.length, equals(3));
      expect(deserialized.objectIds, containsAll(event.objectIds));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = MoveObjectEvent(
        eventId: 'evt_015',
        timestamp: 1699305614000,
        objectIds: ['obj_001'],
        delta: Point(x: 0.0, y: 0.0),
      );

      expect(event.eventType, equals('MoveObjectEvent'));
    });
  });

  group('CreateShapeEvent', () {
    test('serializes and deserializes correctly for rectangle', () {
      const event = CreateShapeEvent(
        eventId: 'evt_016',
        timestamp: 1699305615000,
        shapeId: 'shape_001',
        shapeType: ShapeType.rectangle,
        parameters: {
          'x': 50.0,
          'y': 50.0,
          'width': 200.0,
          'height': 100.0,
          'cornerRadius': 10.0,
        },
        fillColor: '#FF5733',
        strokeColor: '#000000',
        strokeWidth: 2.0,
        opacity: 1.0,
      );

      final json = event.toJson();
      final deserialized = CreateShapeEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.shapeId, equals(event.shapeId));
      expect(deserialized.shapeType, equals(event.shapeType));
      expect(deserialized.parameters, equals(event.parameters));
      expect(deserialized.fillColor, equals(event.fillColor));
      expect(deserialized.strokeColor, equals(event.strokeColor));
      expect(deserialized.strokeWidth, equals(event.strokeWidth));
      expect(deserialized.opacity, equals(event.opacity));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly for star', () {
      const event = CreateShapeEvent(
        eventId: 'evt_017',
        timestamp: 1699305616000,
        shapeId: 'shape_002',
        shapeType: ShapeType.star,
        parameters: {
          'centerX': 300.0,
          'centerY': 200.0,
          'outerRadius': 50.0,
          'innerRadius': 25.0,
          'points': 5.0,
        },
        fillColor: '#FFD700',
      );

      final json = event.toJson();
      final deserialized = CreateShapeEvent.fromJson(json);

      expect(deserialized.shapeType, equals(ShapeType.star));
      expect(deserialized.parameters['points'], equals(5.0));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with minimal fields', () {
      const event = CreateShapeEvent(
        eventId: 'evt_018',
        timestamp: 1699305617000,
        shapeId: 'shape_003',
        shapeType: ShapeType.ellipse,
        parameters: {
          'centerX': 100.0,
          'centerY': 100.0,
          'radiusX': 50.0,
          'radiusY': 30.0,
        },
      );

      final json = event.toJson();
      final deserialized = CreateShapeEvent.fromJson(json);

      expect(deserialized.fillColor, isNull);
      expect(deserialized.strokeColor, isNull);
      expect(deserialized.strokeWidth, isNull);
      expect(deserialized.opacity, isNull);
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = CreateShapeEvent(
        eventId: 'evt_019',
        timestamp: 1699305618000,
        shapeId: 'shape_004',
        shapeType: ShapeType.polygon,
        parameters: {},
      );

      expect(event.eventType, equals('CreateShapeEvent'));
    });
  });

  group('ModifyStyleEvent', () {
    test('serializes and deserializes correctly with all style fields', () {
      const event = ModifyStyleEvent(
        eventId: 'evt_020',
        timestamp: 1699305619000,
        objectId: 'path_001',
        fillColor: '#FF5733',
        strokeColor: '#000000',
        strokeWidth: 3.0,
        opacity: 0.8,
      );

      final json = event.toJson();
      final deserialized = ModifyStyleEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.objectId, equals(event.objectId));
      expect(deserialized.fillColor, equals(event.fillColor));
      expect(deserialized.strokeColor, equals(event.strokeColor));
      expect(deserialized.strokeWidth, equals(event.strokeWidth));
      expect(deserialized.opacity, equals(event.opacity));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with partial style fields', () {
      const event = ModifyStyleEvent(
        eventId: 'evt_021',
        timestamp: 1699305620000,
        objectId: 'shape_002',
        fillColor: '#00FF00',
      );

      final json = event.toJson();
      final deserialized = ModifyStyleEvent.fromJson(json);

      expect(deserialized.fillColor, equals(event.fillColor));
      expect(deserialized.strokeColor, isNull);
      expect(deserialized.strokeWidth, isNull);
      expect(deserialized.opacity, isNull);
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = ModifyStyleEvent(
        eventId: 'evt_022',
        timestamp: 1699305621000,
        objectId: 'obj_001',
      );

      expect(event.eventType, equals('ModifyStyleEvent'));
    });
  });

  group('Polymorphic deserialization', () {
    test('eventFromJson deserializes CreatePathEvent correctly', () {
      final json = {
        'eventType': 'CreatePathEvent',
        'eventId': 'evt_100',
        'timestamp': 1699305700000,
        'pathId': 'path_100',
        'startAnchor': {'x': 10.0, 'y': 20.0},
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<CreatePathEvent>());
      expect((event as CreatePathEvent).pathId, equals('path_100'));
    });

    test('eventFromJson deserializes AddAnchorEvent correctly', () {
      final json = {
        'eventType': 'AddAnchorEvent',
        'eventId': 'evt_101',
        'timestamp': 1699305701000,
        'pathId': 'path_100',
        'position': {'x': 30.0, 'y': 40.0},
        'anchorType': 'line',
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<AddAnchorEvent>());
      expect((event as AddAnchorEvent).pathId, equals('path_100'));
    });

    test('eventFromJson deserializes MoveObjectEvent correctly', () {
      final json = {
        'eventType': 'MoveObjectEvent',
        'eventId': 'evt_102',
        'timestamp': 1699305702000,
        'objectIds': ['obj_1', 'obj_2'],
        'delta': {'x': 5.0, 'y': -5.0},
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<MoveObjectEvent>());
      expect((event as MoveObjectEvent).objectIds.length, equals(2));
    });

    test('eventFromJson deserializes ModifyStyleEvent correctly', () {
      final json = {
        'eventType': 'ModifyStyleEvent',
        'eventId': 'evt_103',
        'timestamp': 1699305703000,
        'objectId': 'obj_1',
        'fillColor': '#FF0000',
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<ModifyStyleEvent>());
      expect((event as ModifyStyleEvent).fillColor, equals('#FF0000'));
    });

    test('eventFromJson throws on unknown event type', () {
      final json = {
        'eventType': 'UnknownEvent',
        'eventId': 'evt_104',
        'timestamp': 1699305704000,
      };

      expect(() => event_schema.eventFromJson(json), throwsArgumentError);
    });

    test('eventFromJson throws on missing event type', () {
      final json = {
        'eventId': 'evt_105',
        'timestamp': 1699305705000,
      };

      expect(() => event_schema.eventFromJson(json), throwsArgumentError);
    });
  });

  group('Enum serialization', () {
    test('AnchorType serializes to string', () {
      expect(AnchorType.line.name, equals('line'));
      expect(AnchorType.bezier.name, equals('bezier'));
    });

    test('ShapeType serializes to string', () {
      expect(ShapeType.rectangle.name, equals('rectangle'));
      expect(ShapeType.ellipse.name, equals('ellipse'));
      expect(ShapeType.star.name, equals('star'));
      expect(ShapeType.polygon.name, equals('polygon'));
    });
  });

  group('Edge cases', () {
    test('handles zero coordinates', () {
      const point = Point(x: 0.0, y: 0.0);
      final json = point.toJson();
      final deserialized = Point.fromJson(json);

      expect(deserialized, equals(point));
    });

    test('handles negative coordinates', () {
      const point = Point(x: -123.45, y: -678.90);
      final json = point.toJson();
      final deserialized = Point.fromJson(json);

      expect(deserialized, equals(point));
    });

    test('handles very large timestamps', () {
      const event = FinishPathEvent(
        eventId: 'evt_200',
        timestamp: 9999999999999,
        pathId: 'path_200',
      );

      final json = event.toJson();
      final deserialized = FinishPathEvent.fromJson(json);

      expect(deserialized.timestamp, equals(9999999999999));
    });

    test('handles empty object list in MoveObjectEvent', () {
      const event = MoveObjectEvent(
        eventId: 'evt_201',
        timestamp: 1699305800000,
        objectIds: [],
        delta: Point(x: 10.0, y: 10.0),
      );

      final json = event.toJson();
      final deserialized = MoveObjectEvent.fromJson(json);

      expect(deserialized.objectIds, isEmpty);
      expect(deserialized, equals(event));
    });

    test('handles empty parameters in CreateShapeEvent', () {
      const event = CreateShapeEvent(
        eventId: 'evt_202',
        timestamp: 1699305801000,
        shapeId: 'shape_200',
        shapeType: ShapeType.ellipse,
        parameters: {},
      );

      final json = event.toJson();
      final deserialized = CreateShapeEvent.fromJson(json);

      expect(deserialized.parameters, isEmpty);
      expect(deserialized, equals(event));
    });
  });
}
