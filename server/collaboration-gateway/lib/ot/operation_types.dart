import 'package:freezed_annotation/freezed_annotation.dart';

part 'operation_types.freezed.dart';
part 'operation_types.g.dart';

/// Base class for all operational transform operations.
///
/// Each operation represents a discrete edit action that can be transformed
/// against concurrent operations to ensure convergence (TP1) and causality
/// preservation (TP2).
@freezed
sealed class OTOperation with _$OTOperation {
  const OTOperation._();

  /// Insert operation - adds a new object at a specific index.
  ///
  /// When transformed against concurrent inserts at the same index,
  /// uses user_id as tiebreaker for deterministic ordering.
  const factory OTOperation.insert({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required String objectId,
    required int index,
    required Map<String, dynamic> objectData,
    required int timestamp,
  }) = InsertOperation;

  /// Delete operation - removes an object by ID.
  ///
  /// When transformed against concurrent deletes of the same object,
  /// becomes a no-op. When transformed against moves/modifies of deleted
  /// objects, those operations become no-ops.
  const factory OTOperation.delete({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required String targetId,
    required int timestamp,
  }) = DeleteOperation;

  /// Move operation - translates an object by a delta.
  ///
  /// When transformed against delete of the same object, becomes no-op.
  /// Otherwise preserves the delta transformation.
  const factory OTOperation.move({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required String targetId,
    required double deltaX,
    required double deltaY,
    required int timestamp,
  }) = MoveOperation;

  /// Modify operation - changes properties of an object.
  ///
  /// When transformed against concurrent modifies of the same property,
  /// uses Last-Write-Wins (LWW) based on server timestamp.
  /// When properties differ, both modifications apply.
  const factory OTOperation.modify({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required String targetId,
    required String propertyPath,
    required dynamic newValue,
    required int timestamp,
  }) = ModifyOperation;

  /// Transform operation - applies matrix transformation to an object.
  ///
  /// Recomputes relative to new coordinate space when needed.
  const factory OTOperation.transform({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required String targetId,
    required List<double> matrix, // 2x3 affine transform matrix
    required int timestamp,
  }) = TransformOperation;

  /// Modify anchor operation - changes properties of a specific anchor point.
  ///
  /// Used for path editing operations that modify individual anchor points.
  const factory OTOperation.modifyAnchor({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required String pathId,
    required int anchorIndex,
    required Map<String, dynamic> anchorData,
    required int timestamp,
  }) = ModifyAnchorOperation;

  /// No-op operation - placeholder for operations that become invalid after transformation.
  ///
  /// Examples: moving a deleted object, deleting an already-deleted object.
  const factory OTOperation.noOp({
    required String operationId,
    required String userId,
    required String sessionId,
    required int localSequence,
    required int serverSequence,
    required int timestamp,
    String? reason,
  }) = NoOpOperation;

  factory OTOperation.fromJson(Map<String, dynamic> json) =>
      _$OTOperationFromJson(json);
}

/// State vector for tracking operation sequences in OT algorithm.
///
/// Tracks both local (client-side) and server-acknowledged sequences
/// to properly transform operations in flight.
@freezed
class OTState with _$OTState {
  const factory OTState({
    required int localSequence,
    required int serverSequence,
    @Default([]) List<OTOperation> buffer,
  }) = _OTState;

  factory OTState.fromJson(Map<String, dynamic> json) =>
      _$OTStateFromJson(json);
}
