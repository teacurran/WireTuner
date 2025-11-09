import 'package:test/test.dart';
import 'package:vector_engine/src/geometry.dart';
import 'package:vector_engine/src/hit_testing/hit_tester.dart';

void main() {
  group('HitTester construction', () {
    test('empty hit tester', () {
      final hitTester = HitTester.empty();
      expect(hitTester.objectCount, equals(0));
    });

    test('build from paths', () {
      final objects = [
        HitTestable.path(
          id: 'path1',
          path: Path.line(start: Point(x: 0, y: 0), end: Point(x: 10, y: 10)),
        ),
      ];

      final hitTester = HitTester.build(objects);
      expect(hitTester.objectCount, equals(1));
    });

    test('build from shapes', () {
      final objects = [
        HitTestable.shape(
          id: 'rect1',
          shape: Shape.rectangle(
            center: Point(x: 5, y: 5),
            width: 10,
            height: 10,
          ),
        ),
      ];

      final hitTester = HitTester.build(objects);
      expect(hitTester.objectCount, equals(1));
    });

    test('build from mixed objects', () {
      final objects = [
        HitTestable.path(
          id: 'path1',
          path: Path.line(start: Point(x: 0, y: 0), end: Point(x: 10, y: 10)),
        ),
        HitTestable.shape(
          id: 'rect1',
          shape: Shape.rectangle(
            center: Point(x: 5, y: 5),
            width: 10,
            height: 10,
          ),
        ),
      ];

      final hitTester = HitTester.build(objects);
      expect(hitTester.objectCount, equals(2));
    });
  });

  group('HitTester anchor tests', () {
    late HitTester hitTester;

    setUp(() {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 100)),
        ],
        closed: false,
      );

      hitTester = HitTester.build([
        HitTestable.path(id: 'path1', path: path),
      ]);
    });

    test('hit anchor directly', () {
      final hits = hitTester.hitTest(
        point: Point(x: 0, y: 0),
        config: HitTestConfig(anchorTolerance: 5.0),
      );

      final anchorHits = hits.where((h) => h.isAnchorHit);
      expect(anchorHits, isNotEmpty);
      expect(anchorHits.first.objectId, equals('path1'));
      expect(anchorHits.first.anchorIndex, equals(0));
    });

    test('hit anchor within tolerance', () {
      final hits = hitTester.hitTest(
        point: Point(x: 2, y: 2),
        config: HitTestConfig(anchorTolerance: 5.0),
      );

      final anchorHits = hits.where((h) => h.isAnchorHit);
      expect(anchorHits, isNotEmpty);
      expect(anchorHits.first.anchorIndex, equals(0));
    });

    test('miss anchor outside tolerance', () {
      final hits = hitTester.hitTest(
        point: Point(x: 10, y: 10),
        config: HitTestConfig(
          anchorTolerance: 5.0,
          testStrokes: false,
          testFills: false,
        ),
      );

      expect(hits, isEmpty);
    });

    test('hit multiple anchors', () {
      final hits = hitTester.hitTest(
        point: Point(x: 100, y: 0),
        config: HitTestConfig(anchorTolerance: 5.0),
      );

      final anchorHits = hits.where((h) => h.isAnchorHit);
      expect(anchorHits, isNotEmpty);
      expect(anchorHits.first.anchorIndex, equals(1));
    });

    test('anchors disabled in config', () {
      final hits = hitTester.hitTest(
        point: Point(x: 0, y: 0),
        config: HitTestConfig(
          testAnchors: false,
          testStrokes: false,
          testFills: false,
        ),
      );

      expect(hits, isEmpty);
    });
  });

  group('HitTester stroke tests', () {
    late HitTester hitTester;

    setUp(() {
      final path = Path.line(
        start: Point(x: 0, y: 0),
        end: Point(x: 100, y: 0),
      );

      hitTester = HitTester.build([
        HitTestable.path(id: 'line1', path: path),
      ]);
    });

    test('hit stroke directly', () {
      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 0),
        config: HitTestConfig(strokeTolerance: 5.0, testAnchors: false),
      );

      expect(hits, isNotEmpty);
      expect(hits.first.objectId, equals('line1'));
      expect(hits.first.hitType, equals(HitType.pathStroke));
    });

    test('hit stroke within tolerance', () {
      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 3),
        config: HitTestConfig(strokeTolerance: 5.0, testAnchors: false),
      );

      expect(hits, isNotEmpty);
      expect(hits.first.objectId, equals('line1'));
    });

    test('miss stroke outside tolerance', () {
      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 10),
        config: HitTestConfig(strokeTolerance: 5.0, testAnchors: false),
      );

      expect(hits, isEmpty);
    });

    test('strokes disabled in config', () {
      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 0),
        config: HitTestConfig(testStrokes: false, testAnchors: false),
      );

      expect(hits, isEmpty);
    });
  });

  group('HitTester fill tests', () {
    late HitTester hitTester;

    setUp(() {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 100)),
          AnchorPoint.corner(position: Point(x: 0, y: 100)),
        ],
        closed: true,
      );

      hitTester = HitTester.build([
        HitTestable.path(id: 'square1', path: path),
      ]);
    });

    test('hit inside filled path', () {
      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 50),
        config: HitTestConfig(testAnchors: false, testStrokes: false),
      );

      expect(hits, isNotEmpty);
      expect(hits.first.objectId, equals('square1'));
      expect(hits.first.hitType, equals(HitType.pathFill));
    });

    test('miss outside filled path', () {
      final hits = hitTester.hitTest(
        point: Point(x: 150, y: 150),
        config: HitTestConfig(testAnchors: false, testStrokes: false),
      );

      expect(hits, isEmpty);
    });

    test('fills disabled in config', () {
      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 50),
        config: HitTestConfig(testFills: false, testAnchors: false, testStrokes: false),
      );

      expect(hits, isEmpty);
    });

    test('open path never hits fill', () {
      final openPath = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 100)),
        ],
        closed: false,
      );

      final tester = HitTester.build([
        HitTestable.path(id: 'open1', path: openPath),
      ]);

      final hits = tester.hitTest(
        point: Point(x: 50, y: 25),
        config: HitTestConfig(testAnchors: false, testStrokes: false),
      );

      expect(hits, isEmpty);
    });
  });

  group('HitTester priority and sorting', () {
    test('anchors prioritized over strokes', () {
      final path = Path.line(
        start: Point(x: 0, y: 0),
        end: Point(x: 100, y: 0),
      );

      final hitTester = HitTester.build([
        HitTestable.path(id: 'line1', path: path),
      ]);

      final hits = hitTester.hitTest(
        point: Point(x: 0, y: 0),
        config: HitTestConfig(strokeTolerance: 10.0, anchorTolerance: 10.0),
      );

      expect(hits, isNotEmpty);
      // First hit should be anchor (distance 0)
      expect(hits.first.isAnchorHit, isTrue);
      expect(hits.first.distance, closeTo(0.0, 0.01));
    });

    test('results sorted by distance', () {
      final objects = [
        HitTestable.path(
          id: 'far',
          path: Path.line(start: Point(x: 100, y: 0), end: Point(x: 200, y: 0)),
        ),
        HitTestable.path(
          id: 'near',
          path: Path.line(start: Point(x: 0, y: 0), end: Point(x: 50, y: 0)),
        ),
      ];

      final hitTester = HitTester.build(objects);

      final hits = hitTester.hitTest(
        point: Point(x: 25, y: 3),
        config: HitTestConfig(strokeTolerance: 10.0, testAnchors: false),
      );

      expect(hits.length, greaterThan(0));
      // Nearest should be first
      expect(hits.first.objectId, equals('near'));
    });
  });

  group('HitTester shape tests', () {
    test('hit rectangle shape', () {
      final hitTester = HitTester.build([
        HitTestable.shape(
          id: 'rect1',
          shape: Shape.rectangle(
            center: Point(x: 50, y: 50),
            width: 100,
            height: 100,
          ),
        ),
      ]);

      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 0),
        config: HitTestConfig(testAnchors: false),
      );

      expect(hits, isNotEmpty);
      expect(hits.first.objectId, equals('rect1'));
      expect(hits.first.hitType, equals(HitType.shape));
    });

    test('hit ellipse shape', () {
      final hitTester = HitTester.build([
        HitTestable.shape(
          id: 'ellipse1',
          shape: Shape.ellipse(
            center: Point(x: 50, y: 50),
            width: 100,
            height: 100,
          ),
        ),
      ]);

      final hits = hitTester.hitTest(
        point: Point(x: 50, y: 50),
        config: HitTestConfig(testAnchors: false),
      );

      expect(hits, isNotEmpty);
      expect(hits.first.objectId, equals('ellipse1'));
    });
  });

  group('HitTester bounds queries', () {
    late HitTester hitTester;

    setUp(() {
      final objects = List.generate(
        10,
        (i) => HitTestable.shape(
          id: 'obj$i',
          shape: Shape.rectangle(
            center: Point(x: i * 20.0 + 5, y: 5),
            width: 10,
            height: 10,
          ),
        ),
      );

      hitTester = HitTester.build(objects);
    });

    test('query bounds intersecting objects', () {
      final queryBounds = Bounds.fromLTRB(left: 0, top: 0, right: 50, bottom: 10);
      final hits = hitTester.hitTestBounds(queryBounds);

      // Should hit objects 0, 1, 2
      expect(hits.length, greaterThanOrEqualTo(3));
    });

    test('query bounds with no intersections', () {
      final queryBounds = Bounds.fromLTRB(left: 300, top: 300, right: 400, bottom: 400);
      final hits = hitTester.hitTestBounds(queryBounds);

      expect(hits, isEmpty);
    });
  });

  group('HitTester zoom scaling', () {
    test('config scaled by zoom', () {
      final config = HitTestConfig(
        strokeTolerance: 10.0,
        anchorTolerance: 8.0,
      );

      final scaled = config.scaledByZoom(2.0);

      expect(scaled.strokeTolerance, closeTo(5.0, 0.01));
      expect(scaled.anchorTolerance, closeTo(4.0, 0.01));
      expect(scaled.bezierSamples, equals(config.bezierSamples));
    });

    test('zoom scaling maintains hit area', () {
      final path = Path.line(
        start: Point(x: 0, y: 0),
        end: Point(x: 100, y: 0),
      );

      final hitTester = HitTester.build([
        HitTestable.path(id: 'line1', path: path),
      ]);

      // At 1x zoom, 5px tolerance
      final hits1x = hitTester.hitTest(
        point: Point(x: 50, y: 4),
        config: HitTestConfig(strokeTolerance: 5.0, testAnchors: false),
      );

      // At 2x zoom, world-space point is half, but tolerance is also halved
      // So same screen-space hit
      final hits2x = hitTester.hitTest(
        point: Point(x: 50, y: 2),
        config: HitTestConfig(strokeTolerance: 5.0, testAnchors: false).scaledByZoom(2.0),
      );

      expect(hits1x.isNotEmpty, equals(hits2x.isNotEmpty));
    });
  });

  group('HitTester nearest query', () {
    test('hitTestNearest returns single result', () {
      final objects = [
        HitTestable.path(
          id: 'path1',
          path: Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 0)),
        ),
        HitTestable.path(
          id: 'path2',
          path: Path.line(start: Point(x: 0, y: 50), end: Point(x: 100, y: 50)),
        ),
      ];

      final hitTester = HitTester.build(objects);

      final hit = hitTester.hitTestNearest(
        point: Point(x: 50, y: 2),
        config: HitTestConfig(testAnchors: false),
      );

      expect(hit, isNotNull);
      expect(hit!.objectId, equals('path1')); // Nearest
    });

    test('hitTestNearest returns null when no hits', () {
      final hitTester = HitTester.build([
        HitTestable.path(
          id: 'path1',
          path: Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 0)),
        ),
      ]);

      final hit = hitTester.hitTestNearest(
        point: Point(x: 500, y: 500),
        config: HitTestConfig(strokeTolerance: 1.0),
      );

      expect(hit, isNull);
    });
  });

  group('HitTester statistics', () {
    test('get BVH stats', () {
      final objects = List.generate(
        100,
        (i) => HitTestable.path(
          id: 'path$i',
          path: Path.line(
            start: Point(x: i * 10.0, y: 0),
            end: Point(x: i * 10.0 + 5, y: 5),
          ),
        ),
      );

      final hitTester = HitTester.build(objects);
      final stats = hitTester.getStats();

      expect(stats.totalEntries, equals(100));
      expect(stats.leafCount, greaterThan(0));
    });
  });

  group('HitTestResult', () {
    test('isAnchorHit when anchor index is present', () {
      final result = HitTestResult(
        objectId: 'obj1',
        anchorIndex: 0,
        distance: 1.0,
        hitType: HitType.anchor,
      );

      expect(result.isAnchorHit, isTrue);
      expect(result.isObjectHit, isFalse);
    });

    test('isObjectHit when anchor index is null', () {
      final result = HitTestResult(
        objectId: 'obj1',
        anchorIndex: null,
        distance: 1.0,
        hitType: HitType.pathStroke,
      );

      expect(result.isAnchorHit, isFalse);
      expect(result.isObjectHit, isTrue);
    });

    test('toString includes all fields', () {
      final result = HitTestResult(
        objectId: 'obj1',
        anchorIndex: 2,
        distance: 3.14,
        hitType: HitType.anchor,
      );

      final str = result.toString();
      expect(str, contains('obj1'));
      expect(str, contains('2'));
      expect(str, contains('3.14'));
      expect(str, contains('anchor'));
    });
  });
}
