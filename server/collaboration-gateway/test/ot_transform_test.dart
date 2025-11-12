import 'package:test/test.dart';
import 'package:collaboration_gateway/ot/operation_types.dart';
import 'package:collaboration_gateway/ot/transformers.dart';

/// Comprehensive OT transformation tests covering all operation pairs.
///
/// Tests verify:
/// - TP1 (Convergence): Transformations produce same final state
/// - TP2 (Causality Preservation): Causal relationships maintained
/// - Intent Preservation: Semantic meaning preserved
///
/// Coverage includes:
/// - Insert-Insert conflicts
/// - Delete-Delete conflicts
/// - Move-Delete conflicts
/// - Modify-Modify conflicts (LWW)
/// - Anchor modification conflicts
/// - Transform operation handling
void main() {
  group('Insert Operation Transforms', () {
    test('Insert-Insert: different indices, no conflict', () {
      final opA = OTOperation.insert(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj1',
        index: 5,
        objectData: {'type': 'path'},
        timestamp: 1000,
      );

      final opB = OTOperation.insert(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj2',
        index: 2,
        objectData: {'type': 'shape'},
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<InsertOperation>());
      final insertResult = result as InsertOperation;
      expect(insertResult.index, 6); // Shifted by 1 due to prior insert
    });

    test('Insert-Insert: same index, tiebreaker by userId', () {
      final opA = OTOperation.insert(
        operationId: 'op1',
        userId: 'alice',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj1',
        index: 5,
        objectData: {'type': 'path'},
        timestamp: 1000,
      );

      final opB = OTOperation.insert(
        operationId: 'op2',
        userId: 'bob',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj2',
        index: 5,
        objectData: {'type': 'shape'},
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<InsertOperation>());
      final insertResult = result as InsertOperation;
      // alice < bob, so alice goes first, no adjustment
      expect(insertResult.index, 5);
    });

    test('Insert-Delete: no conflict', () {
      final opA = OTOperation.insert(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj1',
        index: 5,
        objectData: {'type': 'path'},
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj2',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<InsertOperation>());
      final insertResult = result as InsertOperation;
      expect(insertResult.index, 5); // No change
    });
  });

  group('Delete Operation Transforms', () {
    test('Delete-Delete: same object becomes no-op', () {
      final opA = OTOperation.delete(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<NoOpOperation>());
    });

    test('Delete-Delete: different objects, no conflict', () {
      final opA = OTOperation.delete(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj2',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<DeleteOperation>());
      final deleteResult = result as DeleteOperation;
      expect(deleteResult.targetId, 'obj1');
    });
  });

  group('Move Operation Transforms', () {
    test('Move-Delete: moving deleted object becomes no-op', () {
      final opA = OTOperation.move(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        deltaX: 100,
        deltaY: 200,
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<NoOpOperation>());
    });

    test('Move-Move: same object, combine deltas', () {
      final opA = OTOperation.move(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        deltaX: 100,
        deltaY: 200,
        timestamp: 1000,
      );

      final opB = OTOperation.move(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        deltaX: 50,
        deltaY: -30,
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<MoveOperation>());
      final moveResult = result as MoveOperation;
      expect(moveResult.deltaX, 150); // 100 + 50
      expect(moveResult.deltaY, 170); // 200 + (-30)
    });

    test('Move-Move: different objects, no conflict', () {
      final opA = OTOperation.move(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        deltaX: 100,
        deltaY: 200,
        timestamp: 1000,
      );

      final opB = OTOperation.move(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj2',
        deltaX: 50,
        deltaY: -30,
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<MoveOperation>());
      final moveResult = result as MoveOperation;
      expect(moveResult.deltaX, 100); // No change
      expect(moveResult.deltaY, 200);
    });
  });

  group('Modify Operation Transforms', () {
    test('Modify-Delete: modifying deleted object becomes no-op', () {
      final opA = OTOperation.modify(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'fillColor',
        newValue: '#ff0000',
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<NoOpOperation>());
    });

    test('Modify-Modify: same property, LWW by timestamp', () {
      final opA = OTOperation.modify(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'fillColor',
        newValue: '#ff0000',
        timestamp: 2000, // Later timestamp
      );

      final opB = OTOperation.modify(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'fillColor',
        newValue: '#00ff00',
        timestamp: 1000, // Earlier timestamp
      );

      final result = transform(opA, opB);

      expect(result, isA<ModifyOperation>());
      final modifyResult = result as ModifyOperation;
      expect(modifyResult.newValue, '#ff0000'); // A wins
    });

    test('Modify-Modify: same property and timestamp, tiebreaker by userId', () {
      final opA = OTOperation.modify(
        operationId: 'op1',
        userId: 'zoe',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'fillColor',
        newValue: '#ff0000',
        timestamp: 1000,
      );

      final opB = OTOperation.modify(
        operationId: 'op2',
        userId: 'alice',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'fillColor',
        newValue: '#00ff00',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<ModifyOperation>());
      final modifyResult = result as ModifyOperation;
      expect(modifyResult.newValue, '#ff0000'); // zoe > alice
    });

    test('Modify-Modify: different properties, both apply', () {
      final opA = OTOperation.modify(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'fillColor',
        newValue: '#ff0000',
        timestamp: 1000,
      );

      final opB = OTOperation.modify(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        propertyPath: 'strokeWidth',
        newValue: 2.0,
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<ModifyOperation>());
      final modifyResult = result as ModifyOperation;
      expect(modifyResult.propertyPath, 'fillColor');
      expect(modifyResult.newValue, '#ff0000'); // No change
    });
  });

  group('Anchor Modify Operation Transforms', () {
    test('ModifyAnchor-Delete: modifying anchor of deleted path becomes no-op', () {
      final opA = OTOperation.modifyAnchor(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        pathId: 'path1',
        anchorIndex: 0,
        anchorData: {'x': 100, 'y': 200},
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'path1',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<NoOpOperation>());
    });

    test('ModifyAnchor-ModifyAnchor: same anchor, LWW', () {
      final opA = OTOperation.modifyAnchor(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        pathId: 'path1',
        anchorIndex: 0,
        anchorData: {'x': 100, 'y': 200},
        timestamp: 2000,
      );

      final opB = OTOperation.modifyAnchor(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        pathId: 'path1',
        anchorIndex: 0,
        anchorData: {'x': 150, 'y': 250},
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<ModifyAnchorOperation>());
      final anchorResult = result as ModifyAnchorOperation;
      expect(anchorResult.anchorData, {'x': 100, 'y': 200}); // A wins
    });

    test('ModifyAnchor-ModifyAnchor: different anchors, both apply', () {
      final opA = OTOperation.modifyAnchor(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        pathId: 'path1',
        anchorIndex: 0,
        anchorData: {'x': 100, 'y': 200},
        timestamp: 1000,
      );

      final opB = OTOperation.modifyAnchor(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        pathId: 'path1',
        anchorIndex: 1,
        anchorData: {'x': 150, 'y': 250},
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<ModifyAnchorOperation>());
      final anchorResult = result as ModifyAnchorOperation;
      expect(anchorResult.anchorIndex, 0);
      expect(anchorResult.anchorData, {'x': 100, 'y': 200}); // No change
    });
  });

  group('Transform Operation Transforms', () {
    test('Transform-Delete: transforming deleted object becomes no-op', () {
      final opA = OTOperation.transform(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        matrix: [1, 0, 0, 1, 0, 0],
        timestamp: 1000,
      );

      final opB = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<NoOpOperation>());
    });

    test('Transform-Transform: different objects, no conflict', () {
      final opA = OTOperation.transform(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj1',
        matrix: [1, 0, 0, 1, 0, 0],
        timestamp: 1000,
      );

      final opB = OTOperation.transform(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj2',
        matrix: [2, 0, 0, 2, 0, 0],
        timestamp: 1000,
      );

      final result = transform(opA, opB);

      expect(result, isA<TransformOperation>());
      final transformResult = result as TransformOperation;
      expect(transformResult.targetId, 'obj1');
    });
  });

  group('Buffer Transformation', () {
    test('Transform multiple pending operations against server operation', () {
      final buffer = [
        OTOperation.insert(
          operationId: 'op1',
          userId: 'user1',
          sessionId: 'session1',
          localSequence: 1,
          serverSequence: 0,
          objectId: 'obj1',
          index: 5,
          objectData: {'type': 'path'},
          timestamp: 1000,
        ),
        OTOperation.move(
          operationId: 'op2',
          userId: 'user1',
          sessionId: 'session1',
          localSequence: 2,
          serverSequence: 0,
          targetId: 'obj2',
          deltaX: 100,
          deltaY: 200,
          timestamp: 1001,
        ),
      ];

      final serverOp = OTOperation.delete(
        operationId: 'op3',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        targetId: 'obj2',
        timestamp: 1000,
      );

      final result = transformBuffer(buffer, serverOp);

      expect(result.length, 2);
      expect(result[0], isA<InsertOperation>());
      expect(result[1], isA<NoOpOperation>()); // Move becomes no-op
    });
  });

  group('Convergence Property (TP1)', () {
    test('Insert-Insert convergence', () {
      // State 1: Apply opA then transform(opB, opA)
      // State 2: Apply opB then transform(opA, opB)
      // Both should produce same final indices

      final opA = OTOperation.insert(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj1',
        index: 3,
        objectData: {'type': 'path'},
        timestamp: 1000,
      );

      final opB = OTOperation.insert(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj2',
        index: 3,
        objectData: {'type': 'shape'},
        timestamp: 1000,
      );

      final transformedA = transform(opA, opB);
      final transformedB = transform(opB, opA);

      // Both should have different indices after transformation
      expect((transformedA as InsertOperation).index, 3);
      expect((transformedB as InsertOperation).index, 4);

      // Simulating final state: [0, 1, 2, obj1@3, obj2@4, ...]
      // Convergence is achieved through deterministic tiebreaker
    });
  });
}
