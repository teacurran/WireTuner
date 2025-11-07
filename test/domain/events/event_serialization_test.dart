import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/style_events.dart';
import 'package:wiretuner/domain/events/selection_events.dart';
import 'package:wiretuner/domain/events/viewport_events.dart';
import 'package:wiretuner/domain/events/file_events.dart';
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

  group('DeleteObjectEvent', () {
    test('serializes and deserializes correctly with single object', () {
      const event = DeleteObjectEvent(
        eventId: 'evt_300',
        timestamp: 1699305900000,
        objectIds: ['path_001'],
      );

      final json = event.toJson();
      final deserialized = DeleteObjectEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.objectIds, equals(event.objectIds));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with multiple objects', () {
      const event = DeleteObjectEvent(
        eventId: 'evt_301',
        timestamp: 1699305901000,
        objectIds: ['path_001', 'shape_002', 'path_003'],
      );

      final json = event.toJson();
      final deserialized = DeleteObjectEvent.fromJson(json);

      expect(deserialized.objectIds.length, equals(3));
      expect(deserialized.objectIds, containsAll(event.objectIds));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = DeleteObjectEvent(
        eventId: 'evt_302',
        timestamp: 1699305902000,
        objectIds: ['obj_001'],
      );

      expect(event.eventType, equals('DeleteObjectEvent'));
    });
  });

  group('SelectObjectsEvent', () {
    test('serializes and deserializes correctly with replace mode', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_400',
        timestamp: 1699306000000,
        objectIds: ['path_001', 'shape_002'],
        mode: SelectionMode.replace,
      );

      final json = event.toJson();
      final deserialized = SelectObjectsEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.objectIds, equals(event.objectIds));
      expect(deserialized.mode, equals(SelectionMode.replace));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly with add mode', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_401',
        timestamp: 1699306001000,
        objectIds: ['path_003'],
        mode: SelectionMode.add,
      );

      final json = event.toJson();
      final deserialized = SelectObjectsEvent.fromJson(json);

      expect(deserialized.mode, equals(SelectionMode.add));
      expect(deserialized, equals(event));
    });

    test('defaults to replace mode', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_402',
        timestamp: 1699306002000,
        objectIds: ['obj_001'],
      );

      final json = event.toJson();
      final deserialized = SelectObjectsEvent.fromJson(json);

      expect(deserialized.mode, equals(SelectionMode.replace));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_403',
        timestamp: 1699306003000,
        objectIds: ['obj_001'],
      );

      expect(event.eventType, equals('SelectObjectsEvent'));
    });
  });

  group('DeselectObjectsEvent', () {
    test('serializes and deserializes correctly', () {
      const event = DeselectObjectsEvent(
        eventId: 'evt_410',
        timestamp: 1699306100000,
        objectIds: ['path_001', 'shape_002'],
      );

      final json = event.toJson();
      final deserialized = DeselectObjectsEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.objectIds, equals(event.objectIds));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = DeselectObjectsEvent(
        eventId: 'evt_411',
        timestamp: 1699306101000,
        objectIds: ['obj_001'],
      );

      expect(event.eventType, equals('DeselectObjectsEvent'));
    });
  });

  group('ClearSelectionEvent', () {
    test('serializes and deserializes correctly', () {
      const event = ClearSelectionEvent(
        eventId: 'evt_420',
        timestamp: 1699306200000,
      );

      final json = event.toJson();
      final deserialized = ClearSelectionEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = ClearSelectionEvent(
        eventId: 'evt_421',
        timestamp: 1699306201000,
      );

      expect(event.eventType, equals('ClearSelectionEvent'));
    });
  });

  group('ViewportPanEvent', () {
    test('serializes and deserializes correctly', () {
      const event = ViewportPanEvent(
        eventId: 'evt_500',
        timestamp: 1699306500000,
        delta: Point(x: 50.0, y: -30.0),
      );

      final json = event.toJson();
      final deserialized = ViewportPanEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.delta, equals(event.delta));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = ViewportPanEvent(
        eventId: 'evt_501',
        timestamp: 1699306501000,
        delta: Point(x: 0.0, y: 0.0),
      );

      expect(event.eventType, equals('ViewportPanEvent'));
    });
  });

  group('ViewportZoomEvent', () {
    test('serializes and deserializes correctly', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_510',
        timestamp: 1699306600000,
        factor: 2.0,
        focalPoint: Point(x: 400.0, y: 300.0),
      );

      final json = event.toJson();
      final deserialized = ViewportZoomEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.factor, equals(event.factor));
      expect(deserialized.focalPoint, equals(event.focalPoint));
      expect(deserialized, equals(event));
    });

    test('handles zoom out (factor < 1.0)', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_511',
        timestamp: 1699306601000,
        factor: 0.5,
        focalPoint: Point(x: 200.0, y: 150.0),
      );

      final json = event.toJson();
      final deserialized = ViewportZoomEvent.fromJson(json);

      expect(deserialized.factor, equals(0.5));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_512',
        timestamp: 1699306602000,
        factor: 1.0,
        focalPoint: Point(x: 0.0, y: 0.0),
      );

      expect(event.eventType, equals('ViewportZoomEvent'));
    });
  });

  group('ViewportResetEvent', () {
    test('serializes and deserializes correctly', () {
      const event = ViewportResetEvent(
        eventId: 'evt_520',
        timestamp: 1699306700000,
      );

      final json = event.toJson();
      final deserialized = ViewportResetEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = ViewportResetEvent(
        eventId: 'evt_521',
        timestamp: 1699306701000,
      );

      expect(event.eventType, equals('ViewportResetEvent'));
    });
  });

  group('SaveDocumentEvent', () {
    test('serializes and deserializes correctly with file path', () {
      const event = SaveDocumentEvent(
        eventId: 'evt_600',
        timestamp: 1699306800000,
        filePath: '/path/to/document.wiretuner',
      );

      final json = event.toJson();
      final deserialized = SaveDocumentEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.filePath, equals(event.filePath));
      expect(deserialized, equals(event));
    });

    test('serializes and deserializes correctly without file path', () {
      const event = SaveDocumentEvent(
        eventId: 'evt_601',
        timestamp: 1699306801000,
      );

      final json = event.toJson();
      final deserialized = SaveDocumentEvent.fromJson(json);

      expect(deserialized.filePath, isNull);
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = SaveDocumentEvent(
        eventId: 'evt_602',
        timestamp: 1699306802000,
      );

      expect(event.eventType, equals('SaveDocumentEvent'));
    });
  });

  group('LoadDocumentEvent', () {
    test('serializes and deserializes correctly', () {
      const event = LoadDocumentEvent(
        eventId: 'evt_610',
        timestamp: 1699306900000,
        filePath: '/path/to/document.wiretuner',
      );

      final json = event.toJson();
      final deserialized = LoadDocumentEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.filePath, equals(event.filePath));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = LoadDocumentEvent(
        eventId: 'evt_611',
        timestamp: 1699306901000,
        filePath: '/path/to/doc.wiretuner',
      );

      expect(event.eventType, equals('LoadDocumentEvent'));
    });
  });

  group('DocumentLoadedEvent', () {
    test('serializes and deserializes correctly', () {
      const event = DocumentLoadedEvent(
        eventId: 'evt_620',
        timestamp: 1699307000000,
        filePath: '/path/to/document.wiretuner',
        eventCount: 1234,
      );

      final json = event.toJson();
      final deserialized = DocumentLoadedEvent.fromJson(json);

      expect(deserialized.eventId, equals(event.eventId));
      expect(deserialized.timestamp, equals(event.timestamp));
      expect(deserialized.filePath, equals(event.filePath));
      expect(deserialized.eventCount, equals(event.eventCount));
      expect(deserialized, equals(event));
    });

    test('eventType field is correct', () {
      const event = DocumentLoadedEvent(
        eventId: 'evt_621',
        timestamp: 1699307001000,
        filePath: '/path/to/doc.wiretuner',
        eventCount: 0,
      );

      expect(event.eventType, equals('DocumentLoadedEvent'));
    });
  });

  group('Polymorphic deserialization - New Events', () {
    test('eventFromJson deserializes DeleteObjectEvent correctly', () {
      final json = {
        'eventType': 'DeleteObjectEvent',
        'eventId': 'evt_700',
        'timestamp': 1699307100000,
        'objectIds': ['obj_1', 'obj_2'],
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<DeleteObjectEvent>());
      expect((event as DeleteObjectEvent).objectIds.length, equals(2));
    });

    test('eventFromJson deserializes SelectObjectsEvent correctly', () {
      final json = {
        'eventType': 'SelectObjectsEvent',
        'eventId': 'evt_701',
        'timestamp': 1699307101000,
        'objectIds': ['obj_1'],
        'mode': 'add',
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<SelectObjectsEvent>());
      expect((event as SelectObjectsEvent).mode, equals(SelectionMode.add));
    });

    test('eventFromJson deserializes DeselectObjectsEvent correctly', () {
      final json = {
        'eventType': 'DeselectObjectsEvent',
        'eventId': 'evt_702',
        'timestamp': 1699307102000,
        'objectIds': ['obj_1'],
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<DeselectObjectsEvent>());
    });

    test('eventFromJson deserializes ClearSelectionEvent correctly', () {
      final json = {
        'eventType': 'ClearSelectionEvent',
        'eventId': 'evt_703',
        'timestamp': 1699307103000,
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<ClearSelectionEvent>());
    });

    test('eventFromJson deserializes ViewportPanEvent correctly', () {
      final json = {
        'eventType': 'ViewportPanEvent',
        'eventId': 'evt_704',
        'timestamp': 1699307104000,
        'delta': {'x': 10.0, 'y': -5.0},
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<ViewportPanEvent>());
      expect((event as ViewportPanEvent).delta.x, equals(10.0));
    });

    test('eventFromJson deserializes ViewportZoomEvent correctly', () {
      final json = {
        'eventType': 'ViewportZoomEvent',
        'eventId': 'evt_705',
        'timestamp': 1699307105000,
        'factor': 2.0,
        'focalPoint': {'x': 400.0, 'y': 300.0},
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<ViewportZoomEvent>());
      expect((event as ViewportZoomEvent).factor, equals(2.0));
    });

    test('eventFromJson deserializes ViewportResetEvent correctly', () {
      final json = {
        'eventType': 'ViewportResetEvent',
        'eventId': 'evt_706',
        'timestamp': 1699307106000,
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<ViewportResetEvent>());
    });

    test('eventFromJson deserializes SaveDocumentEvent correctly', () {
      final json = {
        'eventType': 'SaveDocumentEvent',
        'eventId': 'evt_707',
        'timestamp': 1699307107000,
        'filePath': '/path/to/doc.wiretuner',
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<SaveDocumentEvent>());
      expect((event as SaveDocumentEvent).filePath, equals('/path/to/doc.wiretuner'));
    });

    test('eventFromJson deserializes LoadDocumentEvent correctly', () {
      final json = {
        'eventType': 'LoadDocumentEvent',
        'eventId': 'evt_708',
        'timestamp': 1699307108000,
        'filePath': '/path/to/doc.wiretuner',
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<LoadDocumentEvent>());
    });

    test('eventFromJson deserializes DocumentLoadedEvent correctly', () {
      final json = {
        'eventType': 'DocumentLoadedEvent',
        'eventId': 'evt_709',
        'timestamp': 1699307109000,
        'filePath': '/path/to/doc.wiretuner',
        'eventCount': 500,
      };

      final event = event_schema.eventFromJson(json);

      expect(event, isA<DocumentLoadedEvent>());
      expect((event as DocumentLoadedEvent).eventCount, equals(500));
    });
  });

  group('Enum serialization - New Enums', () {
    test('SelectionMode serializes to string', () {
      expect(SelectionMode.replace.name, equals('replace'));
      expect(SelectionMode.add.name, equals('add'));
      expect(SelectionMode.toggle.name, equals('toggle'));
      expect(SelectionMode.subtract.name, equals('subtract'));
    });
  });

  group('Validation and error cases', () {
    test('DeleteObjectEvent with empty object list is valid', () {
      const event = DeleteObjectEvent(
        eventId: 'evt_800',
        timestamp: 1699307200000,
        objectIds: [],
      );

      final json = event.toJson();
      final deserialized = DeleteObjectEvent.fromJson(json);

      expect(deserialized.objectIds, isEmpty);
      expect(deserialized, equals(event));
    });

    test('SelectObjectsEvent with empty object list is valid', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_801',
        timestamp: 1699307201000,
        objectIds: [],
      );

      final json = event.toJson();
      final deserialized = SelectObjectsEvent.fromJson(json);

      expect(deserialized.objectIds, isEmpty);
      expect(deserialized, equals(event));
    });

    test('ViewportZoomEvent with zero factor serializes correctly', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_802',
        timestamp: 1699307202000,
        factor: 0.0,
        focalPoint: Point(x: 0.0, y: 0.0),
      );

      final json = event.toJson();
      final deserialized = ViewportZoomEvent.fromJson(json);

      expect(deserialized.factor, equals(0.0));
      expect(deserialized, equals(event));
    });

    test('ViewportZoomEvent with negative factor serializes correctly', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_803',
        timestamp: 1699307203000,
        factor: -1.0,
        focalPoint: Point(x: 100.0, y: 100.0),
      );

      final json = event.toJson();
      final deserialized = ViewportZoomEvent.fromJson(json);

      expect(deserialized.factor, equals(-1.0));
      expect(deserialized, equals(event));
    });

    test('DocumentLoadedEvent with zero event count is valid', () {
      const event = DocumentLoadedEvent(
        eventId: 'evt_804',
        timestamp: 1699307204000,
        filePath: '/path/to/empty.wiretuner',
        eventCount: 0,
      );

      final json = event.toJson();
      final deserialized = DocumentLoadedEvent.fromJson(json);

      expect(deserialized.eventCount, equals(0));
      expect(deserialized, equals(event));
    });
  });
}
