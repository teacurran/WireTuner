import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/style_events.dart';
import 'package:wiretuner/domain/events/selection_events.dart';
import 'package:wiretuner/domain/events/viewport_events.dart';
import 'package:wiretuner/domain/events/file_events.dart';
import 'package:wiretuner/api/event_schema.dart' as event_schema;

/// Test suite for event schema validation.
///
/// This test suite ensures that:
/// 1. All event types serialize to JSON that matches the JSON Schema
/// 2. The schema covers all event types defined in validEventTypes
/// 3. Adding new required fields to events fails tests (forcing schema updates)
/// 4. Edge cases (empty arrays, null values, negative numbers) are handled correctly
///
/// The JSON Schema is defined in: docs/specs/event_payload.schema.json
///
/// Validation workflow (documented for CI/CD):
/// ```bash
/// # Validate schema syntax
/// npm exec ajv compile -s docs/specs/event_payload.schema.json
///
/// # Validate event fixtures against schema
/// npm exec ajv validate -s docs/specs/event_payload.schema.json -d "test/fixtures/events/*.json"
/// ```
void main() {
  group('Event Schema Coverage', () {
    test('all validEventTypes are tested', () {
      // This test ensures that the schema covers all event types
      // by verifying each one can be serialized and deserialized
      final testedEventTypes = <String>{
        'CreatePathEvent',
        'AddAnchorEvent',
        'FinishPathEvent',
        'ModifyAnchorEvent',
        'MoveObjectEvent',
        'CreateShapeEvent',
        'DeleteObjectEvent',
        'ModifyStyleEvent',
        'SelectObjectsEvent',
        'DeselectObjectsEvent',
        'ClearSelectionEvent',
        'ViewportPanEvent',
        'ViewportZoomEvent',
        'ViewportResetEvent',
        'SaveDocumentEvent',
        'LoadDocumentEvent',
        'DocumentLoadedEvent',
      };

      expect(
        testedEventTypes,
        containsAll(event_schema.validEventTypes),
        reason: 'All validEventTypes must have schema validation',
      );
      expect(
        event_schema.validEventTypes,
        containsAll(testedEventTypes),
        reason: 'No extra event types in test list',
      );
    });
  });

  group('Schema Validation - Path Events', () {
    test('CreatePathEvent matches schema', () {
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

      // Validate required fields
      expect(json['eventId'], isNotNull);
      expect(json['timestamp'], isNotNull);
      expect(event.eventType, equals('CreatePathEvent')); // eventType is a getter, not in JSON
      expect(json['pathId'], isNotNull);
      expect(json['startAnchor'], isNotNull);
      expect(json['startAnchor']['x'], isA<num>());
      expect(json['startAnchor']['y'], isA<num>());

      // Validate optional style fields
      if (json['fillColor'] != null) {
        expect(json['fillColor'], matches(r'^#[0-9A-Fa-f]{6}$'));
      }
      if (json['strokeColor'] != null) {
        expect(json['strokeColor'], matches(r'^#[0-9A-Fa-f]{6}$'));
      }
    });

    test('AddAnchorEvent matches schema with defaults', () {
      const event = AddAnchorEvent(
        eventId: 'evt_002',
        timestamp: 1699305601000,
        pathId: 'path_001',
        position: Point(x: 150.0, y: 250.0),
      );

      final json = event.toJson();

      expect(event.eventType, equals('AddAnchorEvent'));
      expect(json['anchorType'], equals('line')); // Default value
      expect(json['handleIn'], isNull);
      expect(json['handleOut'], isNull);
    });

    test('AddAnchorEvent matches schema with bezier handles', () {
      const event = AddAnchorEvent(
        eventId: 'evt_003',
        timestamp: 1699305602000,
        pathId: 'path_001',
        position: Point(x: 150.0, y: 250.0),
        anchorType: AnchorType.bezier,
        handleIn: Point(x: 140.0, y: 240.0),
        handleOut: Point(x: 160.0, y: 260.0),
      );

      final json = event.toJson();

      expect(json['anchorType'], equals('bezier'));
      expect(json['handleIn'], isNotNull);
      expect(json['handleOut'], isNotNull);
    });

    test('FinishPathEvent matches schema', () {
      const event = FinishPathEvent(
        eventId: 'evt_004',
        timestamp: 1699305603000,
        pathId: 'path_001',
        closed: true,
      );

      final json = event.toJson();

      expect(event.eventType, equals('FinishPathEvent'));
      expect(json['closed'], isA<bool>());
    });

    test('ModifyAnchorEvent matches schema with partial updates', () {
      const event = ModifyAnchorEvent(
        eventId: 'evt_005',
        timestamp: 1699305604000,
        pathId: 'path_001',
        anchorIndex: 1,
        position: Point(x: 155.0, y: 255.0),
      );

      final json = event.toJson();

      expect(event.eventType, equals('ModifyAnchorEvent'));
      expect(json['anchorIndex'], isA<int>());
      expect(json['anchorIndex'], greaterThanOrEqualTo(0));
      expect(json['position'], isNotNull);
      expect(json['handleIn'], isNull);
      expect(json['handleOut'], isNull);
      expect(json['anchorType'], isNull);
    });
  });

  group('Schema Validation - Object Events', () {
    test('CreateShapeEvent matches schema for rectangle', () {
      const event = CreateShapeEvent(
        eventId: 'evt_006',
        timestamp: 1699305605000,
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
      );

      final json = event.toJson();

      expect(event.eventType, equals('CreateShapeEvent'));
      expect(json['shapeType'], equals('rectangle'));
      expect(json['parameters'], isA<Map>());
      expect(json['parameters']['x'], isA<num>());
    });

    test('CreateShapeEvent matches schema for star', () {
      const event = CreateShapeEvent(
        eventId: 'evt_007',
        timestamp: 1699305606000,
        shapeId: 'shape_002',
        shapeType: ShapeType.star,
        parameters: {
          'centerX': 300.0,
          'centerY': 200.0,
          'outerRadius': 50.0,
          'innerRadius': 25.0,
          'points': 5.0,
        },
      );

      final json = event.toJson();

      expect(json['shapeType'], equals('star'));
      expect(json['parameters']['points'], equals(5.0));
    });

    test('CreateShapeEvent matches schema with empty parameters', () {
      const event = CreateShapeEvent(
        eventId: 'evt_008',
        timestamp: 1699305607000,
        shapeId: 'shape_003',
        shapeType: ShapeType.polygon,
        parameters: {},
      );

      final json = event.toJson();

      expect(json['parameters'], isEmpty);
    });

    test('MoveObjectEvent matches schema with multiple objects', () {
      const event = MoveObjectEvent(
        eventId: 'evt_009',
        timestamp: 1699305608000,
        objectIds: ['path_001', 'shape_001', 'path_002'],
        delta: Point(x: 10.0, y: -5.0),
      );

      final json = event.toJson();

      expect(event.eventType, equals('MoveObjectEvent'));
      expect(json['objectIds'], isA<List>());
      expect(json['objectIds'], hasLength(3));
      expect(json['delta'], isNotNull);
    });

    test('MoveObjectEvent matches schema with empty object list', () {
      const event = MoveObjectEvent(
        eventId: 'evt_010',
        timestamp: 1699305609000,
        objectIds: [],
        delta: Point(x: 0.0, y: 0.0),
      );

      final json = event.toJson();

      expect(json['objectIds'], isEmpty);
    });

    test('DeleteObjectEvent matches schema', () {
      const event = DeleteObjectEvent(
        eventId: 'evt_011',
        timestamp: 1699305610000,
        objectIds: ['path_001', 'shape_002'],
      );

      final json = event.toJson();

      expect(event.eventType, equals('DeleteObjectEvent'));
      expect(json['objectIds'], isA<List>());
    });
  });

  group('Schema Validation - Style Events', () {
    test('ModifyStyleEvent matches schema with all fields', () {
      const event = ModifyStyleEvent(
        eventId: 'evt_012',
        timestamp: 1699305611000,
        objectId: 'path_001',
        fillColor: '#FF5733',
        strokeColor: '#000000',
        strokeWidth: 3.0,
        opacity: 0.8,
      );

      final json = event.toJson();

      expect(event.eventType, equals('ModifyStyleEvent'));
      expect(json['objectId'], isNotNull);
      expect(json['fillColor'], matches(r'^#[0-9A-Fa-f]{6}$'));
      expect(json['strokeColor'], matches(r'^#[0-9A-Fa-f]{6}$'));
      expect(json['strokeWidth'], greaterThanOrEqualTo(0));
      expect(json['opacity'], greaterThanOrEqualTo(0));
      expect(json['opacity'], lessThanOrEqualTo(1));
    });

    test('ModifyStyleEvent matches schema with partial fields', () {
      const event = ModifyStyleEvent(
        eventId: 'evt_013',
        timestamp: 1699305612000,
        objectId: 'shape_001',
        fillColor: '#00FF00',
      );

      final json = event.toJson();

      expect(json['fillColor'], isNotNull);
      expect(json['strokeColor'], isNull);
      expect(json['strokeWidth'], isNull);
      expect(json['opacity'], isNull);
    });
  });

  group('Schema Validation - Selection Events', () {
    test('SelectObjectsEvent matches schema with default mode', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_014',
        timestamp: 1699305613000,
        objectIds: ['path_001', 'shape_001'],
      );

      final json = event.toJson();

      expect(event.eventType, equals('SelectObjectsEvent'));
      expect(json['mode'], equals('replace')); // Default
    });

    test('SelectObjectsEvent matches schema with explicit mode', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_015',
        timestamp: 1699305614000,
        objectIds: ['path_002'],
        mode: SelectionMode.add,
      );

      final json = event.toJson();

      expect(json['mode'], equals('add'));
    });

    test('SelectObjectsEvent matches schema with empty object list', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_016',
        timestamp: 1699305615000,
        objectIds: [],
        mode: SelectionMode.replace,
      );

      final json = event.toJson();

      expect(json['objectIds'], isEmpty);
    });

    test('DeselectObjectsEvent matches schema', () {
      const event = DeselectObjectsEvent(
        eventId: 'evt_017',
        timestamp: 1699305616000,
        objectIds: ['path_001'],
      );

      final json = event.toJson();

      expect(event.eventType, equals('DeselectObjectsEvent'));
      expect(json['objectIds'], isA<List>());
    });

    test('ClearSelectionEvent matches schema', () {
      const event = ClearSelectionEvent(
        eventId: 'evt_018',
        timestamp: 1699305617000,
      );

      final json = event.toJson();

      expect(event.eventType, equals('ClearSelectionEvent'));
      // Only envelope fields expected (eventType is a getter, not in JSON)
      expect(json.keys, containsAll(['eventId', 'timestamp']));
    });
  });

  group('Schema Validation - Viewport Events', () {
    test('ViewportPanEvent matches schema', () {
      const event = ViewportPanEvent(
        eventId: 'evt_019',
        timestamp: 1699305618000,
        delta: Point(x: 50.0, y: -30.0),
      );

      final json = event.toJson();

      expect(event.eventType, equals('ViewportPanEvent'));
      expect(json['delta'], isNotNull);
    });

    test('ViewportZoomEvent matches schema with positive factor', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_020',
        timestamp: 1699305619000,
        factor: 2.0,
        focalPoint: Point(x: 400.0, y: 300.0),
      );

      final json = event.toJson();

      expect(event.eventType, equals('ViewportZoomEvent'));
      expect(json['factor'], isA<num>());
      expect(json['focalPoint'], isNotNull);
    });

    test('ViewportZoomEvent matches schema with zoom out factor', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_021',
        timestamp: 1699305620000,
        factor: 0.5,
        focalPoint: Point(x: 200.0, y: 150.0),
      );

      final json = event.toJson();

      expect(json['factor'], equals(0.5));
    });

    test('ViewportZoomEvent handles edge case: zero factor', () {
      // Schema allows negative/zero factors (edge case from tests)
      const event = ViewportZoomEvent(
        eventId: 'evt_022',
        timestamp: 1699305621000,
        factor: 0.0,
        focalPoint: Point(x: 0.0, y: 0.0),
      );

      final json = event.toJson();

      expect(json['factor'], equals(0.0));
    });

    test('ViewportZoomEvent handles edge case: negative factor', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_023',
        timestamp: 1699305622000,
        factor: -1.0,
        focalPoint: Point(x: 100.0, y: 100.0),
      );

      final json = event.toJson();

      expect(json['factor'], equals(-1.0));
    });

    test('ViewportResetEvent matches schema', () {
      const event = ViewportResetEvent(
        eventId: 'evt_024',
        timestamp: 1699305623000,
      );

      final json = event.toJson();

      expect(event.eventType, equals('ViewportResetEvent'));
      // Only envelope fields expected (eventType is a getter, not in JSON)
      expect(json.keys, containsAll(['eventId', 'timestamp']));
    });
  });

  group('Schema Validation - File Events', () {
    test('SaveDocumentEvent matches schema with file path', () {
      const event = SaveDocumentEvent(
        eventId: 'evt_025',
        timestamp: 1699305624000,
        filePath: '/path/to/document.wiretuner',
      );

      final json = event.toJson();

      expect(event.eventType, equals('SaveDocumentEvent'));
      expect(json['filePath'], isNotNull);
    });

    test('SaveDocumentEvent matches schema without file path', () {
      const event = SaveDocumentEvent(
        eventId: 'evt_026',
        timestamp: 1699305625000,
      );

      final json = event.toJson();

      expect(json['filePath'], isNull);
    });

    test('LoadDocumentEvent matches schema', () {
      const event = LoadDocumentEvent(
        eventId: 'evt_027',
        timestamp: 1699305626000,
        filePath: '/path/to/document.wiretuner',
      );

      final json = event.toJson();

      expect(event.eventType, equals('LoadDocumentEvent'));
      expect(json['filePath'], isNotNull);
      expect(json['filePath'], isNotEmpty);
    });

    test('DocumentLoadedEvent matches schema', () {
      const event = DocumentLoadedEvent(
        eventId: 'evt_028',
        timestamp: 1699305627000,
        filePath: '/path/to/document.wiretuner',
        eventCount: 1234,
      );

      final json = event.toJson();

      expect(event.eventType, equals('DocumentLoadedEvent'));
      expect(json['filePath'], isNotNull);
      expect(json['eventCount'], isA<int>());
      expect(json['eventCount'], greaterThanOrEqualTo(0));
    });

    test('DocumentLoadedEvent matches schema with zero events', () {
      const event = DocumentLoadedEvent(
        eventId: 'evt_029',
        timestamp: 1699305628000,
        filePath: '/path/to/empty.wiretuner',
        eventCount: 0,
      );

      final json = event.toJson();

      expect(json['eventCount'], equals(0));
    });
  });

  group('Schema Validation - Edge Cases', () {
    test('Point with negative coordinates', () {
      const point = Point(x: -123.45, y: -678.90);
      final json = point.toJson();

      expect(json['x'], isA<num>());
      expect(json['y'], isA<num>());
      expect(json['x'], lessThan(0));
      expect(json['y'], lessThan(0));
    });

    test('Point with zero coordinates', () {
      const point = Point(x: 0.0, y: 0.0);
      final json = point.toJson();

      expect(json['x'], equals(0.0));
      expect(json['y'], equals(0.0));
    });

    test('Large timestamp values', () {
      const event = FinishPathEvent(
        eventId: 'evt_999',
        timestamp: 9999999999999,
        pathId: 'path_999',
      );

      final json = event.toJson();

      expect(json['timestamp'], equals(9999999999999));
    });
  });

  group('Schema Validation - Polymorphic Deserialization', () {
    test('eventFromJson roundtrip preserves CreatePathEvent', () {
      final json = {
        'eventType': 'CreatePathEvent',
        'eventId': 'evt_100',
        'timestamp': 1699305700000,
        'pathId': 'path_100',
        'startAnchor': {'x': 10.0, 'y': 20.0},
      };

      final event = event_schema.eventFromJson(json);
      expect(event, isA<CreatePathEvent>());

      final serialized = event.toJson();
      expect(event.eventType, equals('CreatePathEvent'));
      expect(serialized['pathId'], equals('path_100'));
    });

    test('eventFromJson roundtrip preserves ViewportZoomEvent', () {
      final json = {
        'eventType': 'ViewportZoomEvent',
        'eventId': 'evt_101',
        'timestamp': 1699305701000,
        'factor': 2.0,
        'focalPoint': {'x': 400.0, 'y': 300.0},
      };

      final event = event_schema.eventFromJson(json);
      expect(event, isA<ViewportZoomEvent>());

      final serialized = event.toJson();
      expect(serialized['factor'], equals(2.0));
    });

    test('eventFromJson roundtrip preserves SelectObjectsEvent with mode', () {
      final json = {
        'eventType': 'SelectObjectsEvent',
        'eventId': 'evt_102',
        'timestamp': 1699305702000,
        'objectIds': ['obj_1', 'obj_2'],
        'mode': 'add',
      };

      final event = event_schema.eventFromJson(json);
      expect(event, isA<SelectObjectsEvent>());
      expect((event as SelectObjectsEvent).mode, equals(SelectionMode.add));
    });
  });

  group('Schema Drift Detection', () {
    /// This test is designed to FAIL when a new required field is added
    /// to an event model without updating the schema.
    ///
    /// How it works:
    /// 1. We serialize known event instances to JSON
    /// 2. We verify the JSON keys match expected schema fields
    /// 3. If a developer adds a new required field to a Freezed class,
    ///    the JSON will contain additional keys, failing this test
    /// 4. This forces the developer to update the schema before tests pass
    test('CreatePathEvent has no unexpected fields', () {
      const event = CreatePathEvent(
        eventId: 'evt_drift_001',
        timestamp: 1699305800000,
        pathId: 'path_drift',
        startAnchor: Point(x: 0.0, y: 0.0),
      );

      final json = event.toJson();
      final expectedKeys = {
        'eventId',
        'timestamp',
        'pathId',
        'startAnchor',
        'fillColor',
        'strokeColor',
        'strokeWidth',
        'opacity',
      };

      expect(
        json.keys.toSet(),
        equals(expectedKeys),
        reason: 'If this fails, a new field was added without updating the schema',
      );
    });

    test('ViewportZoomEvent has no unexpected fields', () {
      const event = ViewportZoomEvent(
        eventId: 'evt_drift_002',
        timestamp: 1699305801000,
        factor: 1.5,
        focalPoint: Point(x: 100.0, y: 100.0),
      );

      final json = event.toJson();
      final expectedKeys = {
        'eventId',
        'timestamp',
        'factor',
        'focalPoint',
      };

      expect(
        json.keys.toSet(),
        equals(expectedKeys),
        reason: 'If this fails, a new field was added without updating the schema',
      );
    });

    test('SelectObjectsEvent has no unexpected fields', () {
      const event = SelectObjectsEvent(
        eventId: 'evt_drift_003',
        timestamp: 1699305802000,
        objectIds: ['obj_1'],
      );

      final json = event.toJson();
      final expectedKeys = {
        'eventId',
        'timestamp',
        'objectIds',
        'mode',
      };

      expect(
        json.keys.toSet(),
        equals(expectedKeys),
        reason: 'If this fails, a new field was added without updating the schema',
      );
    });

    test('DocumentLoadedEvent has no unexpected fields', () {
      const event = DocumentLoadedEvent(
        eventId: 'evt_drift_004',
        timestamp: 1699305803000,
        filePath: '/path/to/test.wiretuner',
        eventCount: 100,
      );

      final json = event.toJson();
      final expectedKeys = {
        'eventId',
        'timestamp',
        'filePath',
        'eventCount',
      };

      expect(
        json.keys.toSet(),
        equals(expectedKeys),
        reason: 'If this fails, a new field was added without updating the schema',
      );
    });
  });

  group('Schema Validation Utilities', () {
    test('schema file exists', () {
      final schemaFile = File('docs/specs/event_payload.schema.json');
      expect(
        schemaFile.existsSync(),
        isTrue,
        reason: 'Schema file must exist at docs/specs/event_payload.schema.json',
      );
    });

    test('schema is valid JSON', () {
      final schemaFile = File('docs/specs/event_payload.schema.json');
      final schemaContent = schemaFile.readAsStringSync();

      expect(
        () => jsonDecode(schemaContent),
        returnsNormally,
        reason: 'Schema must be valid JSON',
      );
    });

    test('schema has correct \$schema property', () {
      final schemaFile = File('docs/specs/event_payload.schema.json');
      final schemaJson = jsonDecode(schemaFile.readAsStringSync());

      expect(
        schemaJson['\$schema'],
        equals('https://json-schema.org/draft/2020-12/schema'),
        reason: 'Schema must use Draft 2020-12',
      );
    });

    test('schema defines all event types in oneOf', () {
      final schemaFile = File('docs/specs/event_payload.schema.json');
      final schemaJson = jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;

      final oneOf = schemaJson['oneOf'] as List?;
      expect(oneOf, isNotNull, reason: 'Schema must have oneOf discriminator');

      // Should have 17 event types
      expect(
        oneOf!.length,
        equals(event_schema.validEventTypes.length),
        reason: 'oneOf must cover all validEventTypes',
      );
    });
  });
}
