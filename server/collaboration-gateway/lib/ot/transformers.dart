/// Operational Transform (OT) transformation functions.
///
/// Implements the core OT algorithm as specified in ADR-0002.
/// Each transform function takes two concurrent operations (opA, opB)
/// and returns opA' that preserves intent when applied after opB.
///
/// **Transformation Properties:**
/// - TP1 (Convergence): apply(state, opB); apply(state, transform(opA, opB))
///   produces the same result as apply(state, opA); apply(state, transform(opB, opA))
/// - TP2 (Causality Preservation): Causal relationships are maintained
/// - Intent Preservation: Semantic meaning preserved after transformation
library transformers;

import 'operation_types.dart';

/// Transforms operation A against operation B.
///
/// Returns A' that can be applied after B while preserving A's intent.
/// This is the main entry point for OT transformation.
OTOperation transform(OTOperation opA, OTOperation opB) {
  return opA.when(
    insert: (id, user, session, local, server, objId, index, data, ts) =>
        _transformInsert(opA as InsertOperation, opB),
    delete: (id, user, session, local, server, targetId, ts) =>
        _transformDelete(opA as DeleteOperation, opB),
    move: (id, user, session, local, server, targetId, dx, dy, ts) =>
        _transformMove(opA as MoveOperation, opB),
    modify: (id, user, session, local, server, targetId, propPath, value, ts) =>
        _transformModify(opA as ModifyOperation, opB),
    transform:
        (id, user, session, local, server, targetId, matrix, ts) =>
            _transformTransform(opA as TransformOperation, opB),
    modifyAnchor:
        (id, user, session, local, server, pathId, anchorIdx, data, ts) =>
            _transformModifyAnchor(opA as ModifyAnchorOperation, opB),
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms an Insert operation against another operation.
OTOperation _transformInsert(InsertOperation opA, OTOperation opB) {
  return opB.when(
    insert: (id, user, session, local, server, objId, indexB, data, ts) {
      // Insert-Insert: Both succeed, adjust index based on position
      final opBInsert = opB as InsertOperation;
      if (opA.index < opBInsert.index) {
        return opA; // No change needed
      } else if (opA.index > opBInsert.index) {
        // Shift index to account for prior insert
        return opA.copyWith(index: opA.index + 1);
      } else {
        // Same index: use user_id as tiebreaker for deterministic ordering
        if (opA.userId.compareTo(opBInsert.userId) < 0) {
          return opA; // A goes first
        } else {
          return opA.copyWith(index: opA.index + 1); // B goes first
        }
      }
    },
    delete: (id, user, session, local, server, targetId, ts) {
      // Insert-Delete: No conflict, insert proceeds
      return opA;
    },
    move: (id, user, session, local, server, targetId, dx, dy, ts) {
      // Insert-Move: No conflict
      return opA;
    },
    modify: (id, user, session, local, server, targetId, propPath, value, ts) {
      // Insert-Modify: No conflict
      return opA;
    },
    transform: (id, user, session, local, server, targetId, matrix, ts) {
      // Insert-Transform: No conflict
      return opA;
    },
    modifyAnchor:
        (id, user, session, local, server, pathId, anchorIdx, data, ts) {
      // Insert-ModifyAnchor: No conflict
      return opA;
    },
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms a Delete operation against another operation.
OTOperation _transformDelete(DeleteOperation opA, OTOperation opB) {
  return opB.when(
    insert: (id, user, session, local, server, objId, index, data, ts) {
      // Delete-Insert: No conflict
      return opA;
    },
    delete: (id, user, session, local, server, targetIdB, ts) {
      // Delete-Delete: First delete wins, second becomes no-op
      final opBDelete = opB as DeleteOperation;
      if (opA.targetId == opBDelete.targetId) {
        return OTOperation.noOp(
          operationId: opA.operationId,
          userId: opA.userId,
          sessionId: opA.sessionId,
          localSequence: opA.localSequence,
          serverSequence: opA.serverSequence,
          timestamp: opA.timestamp,
          reason: 'Object already deleted by ${opBDelete.operationId}',
        );
      }
      return opA;
    },
    move: (id, user, session, local, server, targetId, dx, dy, ts) {
      // Delete-Move: No conflict (move will also check if object deleted)
      return opA;
    },
    modify: (id, user, session, local, server, targetId, propPath, value, ts) {
      // Delete-Modify: No conflict (modify will also check if object deleted)
      return opA;
    },
    transform: (id, user, session, local, server, targetId, matrix, ts) {
      // Delete-Transform: No conflict
      return opA;
    },
    modifyAnchor:
        (id, user, session, local, server, pathId, anchorIdx, data, ts) {
      // Delete-ModifyAnchor: If deleting the path, anchor modify becomes no-op
      final opBAnchor = opB as ModifyAnchorOperation;
      if (opA.targetId == opBAnchor.pathId) {
        return OTOperation.noOp(
          operationId: opA.operationId,
          userId: opA.userId,
          sessionId: opA.sessionId,
          localSequence: opA.localSequence,
          serverSequence: opA.serverSequence,
          timestamp: opA.timestamp,
          reason: 'Path deleted, anchor modification ignored',
        );
      }
      return opA;
    },
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms a Move operation against another operation.
OTOperation _transformMove(MoveOperation opA, OTOperation opB) {
  return opB.when(
    insert: (id, user, session, local, server, objId, index, data, ts) {
      // Move-Insert: No conflict
      return opA;
    },
    delete: (id, user, session, local, server, targetIdB, ts) {
      // Move-Delete: If moving deleted object, becomes no-op
      final opBDelete = opB as DeleteOperation;
      if (opA.targetId == opBDelete.targetId) {
        return OTOperation.noOp(
          operationId: opA.operationId,
          userId: opA.userId,
          sessionId: opA.sessionId,
          localSequence: opA.localSequence,
          serverSequence: opA.serverSequence,
          timestamp: opA.timestamp,
          reason: 'Cannot move deleted object ${opA.targetId}',
        );
      }
      return opA;
    },
    move: (id, user, session, local, server, targetIdB, dxB, dyB, ts) {
      // Move-Move: If same object, combine deltas
      final opBMove = opB as MoveOperation;
      if (opA.targetId == opBMove.targetId) {
        // Both operations move the same object - combine the deltas
        // This preserves both users' intents
        return opA.copyWith(
          deltaX: opA.deltaX + opBMove.deltaX,
          deltaY: opA.deltaY + opBMove.deltaY,
        );
      }
      return opA;
    },
    modify: (id, user, session, local, server, targetId, propPath, value, ts) {
      // Move-Modify: No conflict (different operations)
      return opA;
    },
    transform: (id, user, session, local, server, targetId, matrix, ts) {
      // Move-Transform: If same object, move may need coordinate space adjustment
      // For simplicity, keep move as-is (transformation happens in domain layer)
      return opA;
    },
    modifyAnchor:
        (id, user, session, local, server, pathId, anchorIdx, data, ts) {
      // Move-ModifyAnchor: No conflict
      return opA;
    },
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms a Modify operation against another operation.
OTOperation _transformModify(ModifyOperation opA, OTOperation opB) {
  return opB.when(
    insert: (id, user, session, local, server, objId, index, data, ts) {
      // Modify-Insert: No conflict
      return opA;
    },
    delete: (id, user, session, local, server, targetIdB, ts) {
      // Modify-Delete: If modifying deleted object, becomes no-op
      final opBDelete = opB as DeleteOperation;
      if (opA.targetId == opBDelete.targetId) {
        return OTOperation.noOp(
          operationId: opA.operationId,
          userId: opA.userId,
          sessionId: opA.sessionId,
          localSequence: opA.localSequence,
          serverSequence: opA.serverSequence,
          timestamp: opA.timestamp,
          reason: 'Cannot modify deleted object ${opA.targetId}',
        );
      }
      return opA;
    },
    move: (id, user, session, local, server, targetId, dx, dy, ts) {
      // Modify-Move: No conflict
      return opA;
    },
    modify: (id, user, session, local, server, targetIdB, propPathB, valueB,
        ts) {
      // Modify-Modify: Check if same object and property
      final opBModify = opB as ModifyOperation;
      if (opA.targetId == opBModify.targetId &&
          opA.propertyPath == opBModify.propertyPath) {
        // Conflict: Use Last-Write-Wins (LWW) based on server timestamp
        // Server applies timestamp when broadcasting, so use operation timestamp
        if (opA.timestamp > opBModify.timestamp) {
          return opA; // A wins
        } else if (opA.timestamp < opBModify.timestamp) {
          return OTOperation.noOp(
            operationId: opA.operationId,
            userId: opA.userId,
            sessionId: opA.sessionId,
            localSequence: opA.localSequence,
            serverSequence: opA.serverSequence,
            timestamp: opA.timestamp,
            reason: 'LWW conflict: B has later timestamp',
          );
        } else {
          // Same timestamp: use user_id as tiebreaker
          if (opA.userId.compareTo(opBModify.userId) > 0) {
            return opA;
          } else {
            return OTOperation.noOp(
              operationId: opA.operationId,
              userId: opA.userId,
              sessionId: opA.sessionId,
              localSequence: opA.localSequence,
              serverSequence: opA.serverSequence,
              timestamp: opA.timestamp,
              reason: 'LWW conflict: tiebreaker lost',
            );
          }
        }
      }
      // Different properties: both modifications apply
      return opA;
    },
    transform: (id, user, session, local, server, targetId, matrix, ts) {
      // Modify-Transform: No conflict
      return opA;
    },
    modifyAnchor:
        (id, user, session, local, server, pathId, anchorIdx, data, ts) {
      // Modify-ModifyAnchor: No conflict
      return opA;
    },
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms a Transform operation against another operation.
OTOperation _transformTransform(TransformOperation opA, OTOperation opB) {
  return opB.when(
    insert: (id, user, session, local, server, objId, index, data, ts) {
      // Transform-Insert: No conflict
      return opA;
    },
    delete: (id, user, session, local, server, targetIdB, ts) {
      // Transform-Delete: If transforming deleted object, becomes no-op
      final opBDelete = opB as DeleteOperation;
      if (opA.targetId == opBDelete.targetId) {
        return OTOperation.noOp(
          operationId: opA.operationId,
          userId: opA.userId,
          sessionId: opA.sessionId,
          localSequence: opA.localSequence,
          serverSequence: opA.serverSequence,
          timestamp: opA.timestamp,
          reason: 'Cannot transform deleted object ${opA.targetId}',
        );
      }
      return opA;
    },
    move: (id, user, session, local, server, targetId, dx, dy, ts) {
      // Transform-Move: No conflict (move applies after transform)
      return opA;
    },
    modify: (id, user, session, local, server, targetId, propPath, value, ts) {
      // Transform-Modify: No conflict
      return opA;
    },
    transform:
        (id, user, session, local, server, targetIdB, matrixB, ts) {
      // Transform-Transform: If same object, compose transformations
      final opBTransform = opB as TransformOperation;
      if (opA.targetId == opBTransform.targetId) {
        // Compose the transformation matrices
        // For simplicity, apply both (domain layer handles composition)
        return opA;
      }
      return opA;
    },
    modifyAnchor:
        (id, user, session, local, server, pathId, anchorIdx, data, ts) {
      // Transform-ModifyAnchor: No conflict
      return opA;
    },
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms a ModifyAnchor operation against another operation.
OTOperation _transformModifyAnchor(
    ModifyAnchorOperation opA, OTOperation opB) {
  return opB.when(
    insert: (id, user, session, local, server, objId, index, data, ts) {
      // ModifyAnchor-Insert: No conflict
      return opA;
    },
    delete: (id, user, session, local, server, targetIdB, ts) {
      // ModifyAnchor-Delete: If path deleted, becomes no-op
      final opBDelete = opB as DeleteOperation;
      if (opA.pathId == opBDelete.targetId) {
        return OTOperation.noOp(
          operationId: opA.operationId,
          userId: opA.userId,
          sessionId: opA.sessionId,
          localSequence: opA.localSequence,
          serverSequence: opA.serverSequence,
          timestamp: opA.timestamp,
          reason: 'Cannot modify anchor of deleted path ${opA.pathId}',
        );
      }
      return opA;
    },
    move: (id, user, session, local, server, targetId, dx, dy, ts) {
      // ModifyAnchor-Move: No conflict
      return opA;
    },
    modify: (id, user, session, local, server, targetId, propPath, value, ts) {
      // ModifyAnchor-Modify: No conflict
      return opA;
    },
    transform: (id, user, session, local, server, targetId, matrix, ts) {
      // ModifyAnchor-Transform: May need coordinate adjustment
      // Domain layer handles this
      return opA;
    },
    modifyAnchor: (id, user, session, local, server, pathIdB, anchorIdxB, dataB,
        ts) {
      // ModifyAnchor-ModifyAnchor: Check if same path and anchor
      final opBAnchor = opB as ModifyAnchorOperation;
      if (opA.pathId == opBAnchor.pathId &&
          opA.anchorIndex == opBAnchor.anchorIndex) {
        // Same anchor: Use LWW based on timestamp
        if (opA.timestamp > opBAnchor.timestamp) {
          return opA;
        } else if (opA.timestamp < opBAnchor.timestamp) {
          return OTOperation.noOp(
            operationId: opA.operationId,
            userId: opA.userId,
            sessionId: opA.sessionId,
            localSequence: opA.localSequence,
            serverSequence: opA.serverSequence,
            timestamp: opA.timestamp,
            reason: 'LWW conflict on anchor modification',
          );
        } else {
          // Tiebreaker
          if (opA.userId.compareTo(opBAnchor.userId) > 0) {
            return opA;
          } else {
            return OTOperation.noOp(
              operationId: opA.operationId,
              userId: opA.userId,
              sessionId: opA.sessionId,
              localSequence: opA.localSequence,
              serverSequence: opA.serverSequence,
              timestamp: opA.timestamp,
              reason: 'LWW tiebreaker lost',
            );
          }
        }
      }
      // Different anchors: both apply
      return opA;
    },
    noOp: (id, user, session, local, server, ts, reason) => opA,
  );
}

/// Transforms a list of operations against a base operation.
///
/// Used when a client needs to reconcile multiple pending operations
/// against a newly received server operation.
List<OTOperation> transformBuffer(
    List<OTOperation> buffer, OTOperation serverOp) {
  return buffer.map((op) => transform(op, serverOp)).toList();
}
