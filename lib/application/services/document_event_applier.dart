import 'package:flutter/foundation.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart' as events;
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as models;
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/domain/models/transform.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';

/// Applies events to the document by updating the DocumentProvider.
///
/// This service is responsible for translating domain events into document
/// state changes. It listens to events from the EventRecorder and applies
/// them to maintain consistency between the event log and document state.
class DocumentEventApplier {
  /// Creates a document event applier.
  DocumentEventApplier(this._documentProvider);

  final DocumentProvider _documentProvider;

  /// Applies an event to the document.
  void apply(events.EventBase event) {
    debugPrint('[DocumentEventApplier] Applying event: ${event.eventType}');
    if (event is CreatePathEvent) {
      _applyCreatePath(event);
    } else if (event is AddAnchorEvent) {
      _applyAddAnchor(event);
    } else if (event is FinishPathEvent) {
      _applyFinishPath(event);
    } else if (event is ModifyAnchorEvent) {
      _applyModifyAnchor(event);
    } else if (event is CreateShapeEvent) {
      _applyCreateShape(event);
    } else if (event is MoveObjectEvent) {
      _applyMoveObject(event);
    } else if (event is DeleteObjectEvent) {
      _applyDeleteObject(event);
    } else {
      debugPrint('[DocumentEventApplier] Ignoring unknown event: ${event.eventType}');
    }
  }

  /// Applies a CreatePathEvent by creating a new path with initial anchor.
  void _applyCreatePath(CreatePathEvent event) {
    final anchor = models.AnchorPoint(
      position: event.startAnchor,
      anchorType: models.AnchorType.corner,
    );

    // Use Path.fromAnchors which auto-generates segments
    final path = domain.Path.fromAnchors(
      anchors: [anchor],
      closed: false,
    );

    final pathObject = VectorObject.path(
      id: event.pathId,
      path: path,
    );

    _addObjectToFirstLayer(pathObject);
  }

  /// Applies an AddAnchorEvent by adding an anchor to an existing path.
  void _applyAddAnchor(AddAnchorEvent event) {
    _updatePath(event.pathId, (path) {
      final anchor = models.AnchorPoint(
        position: event.position,
        anchorType: event.anchorType == events.AnchorType.bezier
            ? models.AnchorType.smooth
            : models.AnchorType.corner,
        handleIn: event.handleIn,
        handleOut: event.handleOut,
      );

      // Rebuild path with new anchor using fromAnchors
      return domain.Path.fromAnchors(
        anchors: [...path.anchors, anchor],
        closed: path.closed,
      );
    });
  }

  /// Applies a FinishPathEvent by marking a path as finished/closed.
  void _applyFinishPath(FinishPathEvent event) {
    _updatePath(event.pathId, (path) {
      return path.copyWith(closed: event.closed);
    });
  }

  /// Applies a ModifyAnchorEvent by updating an anchor's properties.
  void _applyModifyAnchor(ModifyAnchorEvent event) {
    _updatePath(event.pathId, (path) {
      if (event.anchorIndex >= path.anchors.length) return path;

      final anchor = path.anchors[event.anchorIndex];
      final updatedAnchor = anchor.copyWith(
        position: event.position ?? anchor.position,
        handleIn: event.handleIn != null ? () => event.handleIn : null,
        handleOut: event.handleOut != null ? () => event.handleOut : null,
        anchorType: event.anchorType != null
            ? (event.anchorType == events.AnchorType.bezier
                ? models.AnchorType.smooth
                : models.AnchorType.corner)
            : anchor.anchorType,
      );

      final updatedAnchors = [...path.anchors];
      updatedAnchors[event.anchorIndex] = updatedAnchor;

      return path.copyWith(anchors: updatedAnchors);
    });
  }

  /// Applies a CreateShapeEvent by creating a new parametric shape.
  void _applyCreateShape(CreateShapeEvent event) {
    final Shape shape;

    switch (event.shapeType) {
      case events.ShapeType.rectangle:
        final centerX = event.parameters['centerX'] ?? 0.0;
        final centerY = event.parameters['centerY'] ?? 0.0;
        final width = event.parameters['width'] ?? 100.0;
        final height = event.parameters['height'] ?? 100.0;
        shape = Shape.rectangle(
          center: events.Point(x: centerX, y: centerY),
          width: width,
          height: height,
        );
        break;
      case events.ShapeType.ellipse:
        final centerX = event.parameters['centerX'] ?? 0.0;
        final centerY = event.parameters['centerY'] ?? 0.0;
        final width = event.parameters['width'] ?? 100.0;
        final height = event.parameters['height'] ?? 100.0;
        shape = Shape.ellipse(
          center: events.Point(x: centerX, y: centerY),
          width: width,
          height: height,
        );
        break;
      case events.ShapeType.polygon:
        final centerX = event.parameters['centerX'] ?? 0.0;
        final centerY = event.parameters['centerY'] ?? 0.0;
        final radius = event.parameters['radius'] ?? 50.0;
        final sides = event.parameters['sides']?.toInt() ?? 6;
        shape = Shape.polygon(
          center: events.Point(x: centerX, y: centerY),
          radius: radius,
          sides: sides,
        );
        break;
      case events.ShapeType.star:
        final centerX = event.parameters['centerX'] ?? 0.0;
        final centerY = event.parameters['centerY'] ?? 0.0;
        final outerRadius = event.parameters['outerRadius'] ?? 50.0;
        final innerRadius = event.parameters['innerRadius'] ?? 25.0;
        final points = event.parameters['points']?.toInt() ?? 5;
        shape = Shape.star(
          center: events.Point(x: centerX, y: centerY),
          outerRadius: outerRadius,
          innerRadius: innerRadius,
          pointCount: points,
        );
        break;
    }

    final shapeObject = VectorObject.shape(
      id: event.shapeId,
      shape: shape,
    );

    _addObjectToFirstLayer(shapeObject);
  }

  /// Applies a MoveObjectEvent by translating objects.
  void _applyMoveObject(MoveObjectEvent event) {
    final layers = _documentProvider.document.layers;
    final updatedLayers = <Layer>[];

    // Create translation transform from delta
    final translation = Transform.translate(event.delta.x, event.delta.y);

    for (final layer in layers) {
      final updatedObjects = <VectorObject>[];

      for (final obj in layer.objects) {
        if (event.objectIds.contains(obj.id)) {
          // Apply translation to this object
          final currentTransform = obj.when(
            path: (_, __, transform) => transform,
            shape: (_, __, transform) => transform,
          );

          // Compose: current transform then translation
          // If no existing transform, just use translation
          final newTransform = currentTransform != null
              ? currentTransform.compose(translation)
              : translation;

          // Update object with new transform
          final updatedObj = obj.when(
            path: (id, path, _) => VectorObject.path(
              id: id,
              path: path,
              transform: newTransform,
            ),
            shape: (id, shape, _) => VectorObject.shape(
              id: id,
              shape: shape,
              transform: newTransform,
            ),
          );

          updatedObjects.add(updatedObj);
        } else {
          // Keep object unchanged
          updatedObjects.add(obj);
        }
      }

      updatedLayers.add(layer.copyWith(objects: updatedObjects));
    }

    _documentProvider.updateLayers(updatedLayers);
  }

  /// Applies a DeleteObjectEvent by removing objects from the document.
  void _applyDeleteObject(DeleteObjectEvent event) {
    final layers = _documentProvider.document.layers;
    final updatedLayers = <Layer>[];

    for (final layer in layers) {
      final updatedObjects = layer.objects
          .where((obj) => !event.objectIds.contains(obj.id))
          .toList();

      updatedLayers.add(layer.copyWith(objects: updatedObjects));
    }

    _documentProvider.updateLayers(updatedLayers);
  }

  /// Helper to update a path by ID.
  void _updatePath(String pathId, domain.Path Function(domain.Path) update) {
    final layers = _documentProvider.document.layers;

    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final objIndex = layer.objects.indexWhere(
        (obj) => obj.when(
          path: (id, _, __) => id == pathId,
          shape: (_, __, ___) => false,
        ),
      );

      if (objIndex != -1) {
        final pathObj = layer.objects[objIndex];
        pathObj.when(
          path: (id, path, transform) {
            final updatedPath = update(path);
            final updatedPathObj = VectorObject.path(
              id: id,
              path: updatedPath,
              transform: transform,
            );

            final updatedObjects = [...layer.objects];
            updatedObjects[objIndex] = updatedPathObj;
            final updatedLayer = layer.copyWith(objects: updatedObjects);

            final updatedLayers = [...layers];
            updatedLayers[i] = updatedLayer;
            _documentProvider.updateLayers(updatedLayers);
          },
          shape: (_, __, ___) {},
        );
        return;
      }
    }
  }

  /// Helper to add an object to the first layer.
  void _addObjectToFirstLayer(VectorObject obj) {
    final layers = _documentProvider.document.layers;
    if (layers.isEmpty) {
      final defaultLayer = Layer(
        id: 'layer-default',
        name: 'Layer 1',
        objects: [obj],
      );
      _documentProvider.updateLayers([defaultLayer]);
    } else {
      final firstLayer = layers.first;
      final updatedLayer = firstLayer.copyWith(
        objects: [...firstLayer.objects, obj],
      );
      _documentProvider.updateLayers([
        updatedLayer,
        ...layers.skip(1),
      ]);
    }
  }
}
