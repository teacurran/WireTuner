import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wiretuner/domain/document/json_converters.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/domain/models/transform.dart';

part 'document.freezed.dart';
part 'document.g.dart';

/// Schema version for the document model.
///
/// This version number should be incremented whenever the document structure
/// changes in a way that affects serialization/deserialization. The snapshot
/// serializer uses this version to perform migrations when loading older
/// document formats.
///
/// Version history:
/// - 1: Initial document model (I2.T4)
/// - 2: Multi-artboard support with per-artboard state isolation (I4.T1)
const int kDocumentSchemaVersion = 2;

/// Represents an immutable vector object that can be stored in a layer.
///
/// VectorObject is a discriminated union that can be either a Path or a Shape.
/// This enables polymorphic storage while maintaining type safety and immutability.
///
/// ## Design Rationale
///
/// We use Freezed's union types instead of class inheritance to:
/// - Maintain full immutability (no mutable base class state)
/// - Enable exhaustive pattern matching
/// - Simplify JSON serialization
/// - Avoid vtable overhead
///
/// ## Examples
///
/// Create a path object:
/// ```dart
/// final pathObj = VectorObject.path(
///   id: 'path-1',
///   path: myPath,
/// );
/// ```
///
/// Create a shape object:
/// ```dart
/// final shapeObj = VectorObject.shape(
///   id: 'shape-1',
///   shape: myShape,
/// );
/// ```
///
/// Pattern match on object type:
/// ```dart
/// final bounds = obj.when(
///   path: (id, path, transform) => path.bounds(),
///   shape: (id, shape, transform) => shape.toPath().bounds(),
/// );
/// ```
@freezed
class VectorObject with _$VectorObject {
  const factory VectorObject.path({
    required String id,
    @PathConverter() required Path path,
    @TransformConverter() Transform? transform,
  }) = PathObject;

  const factory VectorObject.shape({
    required String id,
    @ShapeConverter() required Shape shape,
    @TransformConverter() Transform? transform,
  }) = ShapeObject;

  /// Private constructor for accessing methods on Freezed class.
  const VectorObject._();

  /// Creates a VectorObject from JSON.
  factory VectorObject.fromJson(Map<String, dynamic> json) =>
      _$VectorObjectFromJson(json);

  /// Returns the ID of this vector object.
  @override
  String get id => when(
        path: (id, _, __) => id,
        shape: (id, _, __) => id,
      );

  /// Returns the bounding rectangle for this object.
  ///
  /// For paths, returns the path's control point bounds.
  /// For shapes, converts to path first then calculates bounds.
  Rectangle getBounds() => when(
        path: (_, path, __) => path.bounds(),
        shape: (_, shape, __) => shape.toPath().bounds(),
      );

  /// Performs a hit test at the given point.
  ///
  /// Returns true if the point is within the object's bounds.
  /// Note: This is a simple bounds-based hit test. Future iterations
  /// will implement precise geometric hit testing.
  bool hitTest(Point point) {
    final bounds = getBounds();
    return point.x >= bounds.x &&
        point.x <= bounds.x + bounds.width &&
        point.y >= bounds.y &&
        point.y <= bounds.y + bounds.height;
  }
}

/// Represents an immutable layer in the document.
///
/// A layer is a collection of vector objects with properties that control
/// visibility and editability. Layers provide organizational structure and
/// enable users to manage complex documents.
///
/// ## Design Rationale
///
/// Layers use Freezed for immutability and provide query helpers for
/// viewport and hit-test operations. All modifications create new layer
/// instances using copyWith.
///
/// ## Examples
///
/// Create a layer:
/// ```dart
/// final layer = Layer(
///   id: 'layer-1',
///   name: 'Background',
///   objects: [pathObj, shapeObj],
/// );
/// ```
///
/// Find an object:
/// ```dart
/// final obj = layer.findById('path-1');
/// ```
///
/// Hide a layer:
/// ```dart
/// final hidden = layer.copyWith(visible: false);
/// ```
@freezed
class Layer with _$Layer {
  const factory Layer({
    /// Unique identifier for this layer.
    required String id,

    /// Display name shown in the layers panel.
    @Default('Layer') String name,

    /// Whether this layer is visible in the viewport.
    ///
    /// Invisible layers are not rendered but remain in the document.
    @Default(true) bool visible,

    /// Whether this layer is locked for editing.
    ///
    /// Locked layers cannot be modified or selected.
    @Default(false) bool locked,

    /// Ordered list of vector objects in this layer.
    ///
    /// Objects are rendered in order (first object is bottom-most).
    @Default([]) List<VectorObject> objects,
  }) = _Layer;

  /// Private constructor for accessing methods on Freezed class.
  const Layer._();

  /// Creates a Layer from JSON.
  factory Layer.fromJson(Map<String, dynamic> json) => _$LayerFromJson(json);

  /// Returns all objects in this layer as a list.
  ///
  /// The returned list maintains the original ordering.
  List<VectorObject> get allObjects => objects;

  /// Finds an object by ID.
  ///
  /// Returns null if no object with the given ID exists in this layer.
  VectorObject? findById(String objectId) {
    try {
      return objects.firstWhere((obj) => obj.id == objectId);
    } catch (_) {
      return null;
    }
  }

  /// Returns objects that intersect the given point.
  ///
  /// This is useful for hit testing during selection operations.
  /// Objects are returned in reverse order (top-most first) so the
  /// topmost object can be selected.
  List<VectorObject> objectsAtPoint(Point point) =>
      objects.reversed.where((obj) => obj.hitTest(point)).toList();

  /// Returns objects whose bounds intersect the given rectangle.
  ///
  /// This is useful for marquee selection and viewport culling.
  List<VectorObject> objectsInBounds(Rectangle bounds) => objects.where((obj) {
        final objBounds = obj.getBounds();
        return _rectanglesIntersect(objBounds, bounds);
      }).toList();

  /// Helper to check if two rectangles intersect.
  bool _rectanglesIntersect(Rectangle a, Rectangle b) =>
      a.x < b.x + b.width &&
      a.x + a.width > b.x &&
      a.y < b.y + b.height &&
      a.y + a.height > b.y;
}

/// Represents the viewport state for the document.
///
/// The viewport controls how the document is viewed and provides
/// coordinate transformations between world space (document coordinates)
/// and screen space (pixel coordinates).
///
/// ## Examples
///
/// Create a viewport:
/// ```dart
/// final viewport = Viewport(
///   pan: Point(x: 0, y: 0),
///   zoom: 1.0,
///   canvasSize: Size(width: 1920, height: 1080),
/// );
/// ```
///
/// Transform coordinates:
/// ```dart
/// final screenPoint = viewport.toScreen(worldPoint);
/// final worldPoint = viewport.toWorld(screenPoint);
/// ```
@freezed
class Viewport with _$Viewport {
  const factory Viewport({
    /// Pan offset in world coordinates.
    ///
    /// Represents how much the view has been panned from the origin.
    @Default(Point(x: 0, y: 0)) Point pan,

    /// Zoom level (1.0 = 100%, 2.0 = 200%, 0.5 = 50%).
    ///
    /// Values must be positive. Typical range is 0.1 to 10.0.
    @Default(1.0) double zoom,

    /// Size of the canvas in screen pixels.
    ///
    /// This represents the viewport dimensions in pixel coordinates.
    @Default(Size(width: 800, height: 600)) Size canvasSize,
  }) = _Viewport;

  /// Private constructor for accessing methods on Freezed class.
  const Viewport._();

  /// Creates a Viewport from JSON.
  factory Viewport.fromJson(Map<String, dynamic> json) =>
      _$ViewportFromJson(json);

  /// Converts a point from world coordinates to screen coordinates.
  ///
  /// Applies zoom and pan transformations.
  Point toScreen(Point worldPoint) => Point(
        x: (worldPoint.x - pan.x) * zoom + canvasSize.width / 2,
        y: (worldPoint.y - pan.y) * zoom + canvasSize.height / 2,
      );

  /// Converts a point from screen coordinates to world coordinates.
  ///
  /// Inverse of toScreen transformation.
  Point toWorld(Point screenPoint) => Point(
        x: (screenPoint.x - canvasSize.width / 2) / zoom + pan.x,
        y: (screenPoint.y - canvasSize.height / 2) / zoom + pan.y,
      );
}

/// Represents a 2D size with width and height.
///
/// Used for viewport canvas dimensions.
@freezed
class Size with _$Size {
  const factory Size({
    required double width,
    required double height,
  }) = _Size;

  /// Creates a Size from JSON.
  factory Size.fromJson(Map<String, dynamic> json) => _$SizeFromJson(json);
}

/// Represents an artboard within a document.
///
/// An artboard is an independent canvas area with its own layers, viewport,
/// and selection state. Each artboard can be opened in its own window and
/// maintains complete state isolation from other artboards.
///
/// ## Design Rationale (ADR-005)
///
/// Multi-artboard support enables:
/// - Responsive design boards (mobile/tablet/desktop layouts)
/// - Icon grids and asset collections
/// - Device templates with per-screen isolation
/// - Window-per-artboard architecture
///
/// Each artboard encapsulates:
/// - Layer stack (ordered list of layers)
/// - Selection state (selected objects and anchors)
/// - Viewport state (pan, zoom, canvas size)
/// - Visual bounds (position and size on infinite canvas)
///
/// ## Examples
///
/// Create an artboard:
/// ```dart
/// final artboard = Artboard(
///   id: 'artboard-1',
///   name: 'iPhone 14',
///   bounds: Rectangle(x: 0, y: 0, width: 390, height: 844),
///   layers: [layer1, layer2],
/// );
/// ```
@freezed
class Artboard with _$Artboard {
  const factory Artboard({
    /// Unique identifier for this artboard.
    required String id,

    /// Display name shown in the Navigator panel.
    @Default('Artboard') String name,

    /// Position and dimensions on the infinite canvas.
    ///
    /// The bounds define where this artboard appears and its size.
    /// Multiple artboards can be arranged spatially on the canvas.
    @RectangleConverter() required Rectangle bounds,

    /// Background color for the artboard.
    ///
    /// Displayed when no objects cover the artboard area.
    @Default('#FFFFFF') String backgroundColor,

    /// Optional preset identifier (e.g., "iPhone14", "A4", "1080p").
    ///
    /// Used to populate bounds from device/format templates.
    String? preset,

    /// Ordered list of layers in this artboard.
    ///
    /// Layers are rendered bottom-to-top (first layer is bottom-most).
    @Default([]) List<Layer> layers,

    /// Current selection state for this artboard.
    ///
    /// Tracks which objects and anchor points are selected.
    /// Selection is isolated per artboard.
    @Default(Selection()) Selection selection,

    /// Current viewport state for this artboard.
    ///
    /// Controls pan, zoom, and coordinate transformations.
    /// Each artboard window maintains independent viewport state.
    @Default(Viewport()) Viewport viewport,
  }) = _Artboard;

  /// Private constructor for accessing methods on Freezed class.
  const Artboard._();

  /// Creates an Artboard from JSON.
  factory Artboard.fromJson(Map<String, dynamic> json) =>
      _$ArtboardFromJson(json);

  /// Returns all vector objects from all layers in rendering order.
  ///
  /// Objects are returned bottom-to-top: first layer's objects appear first,
  /// within each layer objects are in their layer order.
  List<VectorObject> getAllObjects() =>
      layers.expand((layer) => layer.objects).toList();

  /// Finds an object by ID across all layers.
  ///
  /// Returns null if no object with the given ID exists.
  VectorObject? getObjectById(String objectId) {
    for (final layer in layers) {
      final obj = layer.findById(objectId);
      if (obj != null) return obj;
    }
    return null;
  }

  /// Finds the layer containing the given object ID.
  ///
  /// Returns null if the object is not found in any layer.
  Layer? getLayerContainingObject(String objectId) {
    for (final layer in layers) {
      if (layer.findById(objectId) != null) {
        return layer;
      }
    }
    return null;
  }

  /// Returns objects at the given point across all visible unlocked layers.
  ///
  /// Objects are returned in reverse rendering order (top-most first).
  /// This is useful for hit testing during selection.
  List<VectorObject> objectsAtPoint(Point point) {
    final results = <VectorObject>[];
    // Iterate layers in reverse (top layer first)
    for (final layer in layers.reversed) {
      if (layer.visible && !layer.locked) {
        results.addAll(layer.objectsAtPoint(point));
      }
    }
    return results;
  }

  /// Returns objects within the given bounds across all visible layers.
  ///
  /// This is useful for marquee selection and viewport culling.
  List<VectorObject> objectsInBounds(Rectangle bounds) {
    final results = <VectorObject>[];
    for (final layer in layers) {
      if (layer.visible) {
        results.addAll(layer.objectsInBounds(bounds));
      }
    }
    return results;
  }

  /// Returns all selected objects.
  ///
  /// Objects are returned in rendering order (bottom-to-top).
  List<VectorObject> getSelectedObjects() =>
      getAllObjects().where((obj) => selection.contains(obj.id)).toList();

  /// Returns true if the artboard is empty (no layers or no objects).
  bool get isEmpty =>
      layers.isEmpty || layers.every((layer) => layer.objects.isEmpty);
}

/// Represents the root document aggregate.
///
/// Document is the root entity in the domain model and contains all artboards,
/// which in turn contain layers, vector objects, selection state, and viewport
/// state. It serves as the aggregate root for event sourcing and snapshot
/// persistence.
///
/// ## Design Rationale
///
/// The document uses Freezed for immutability and includes:
/// - Schema version for future migrations
/// - Ordered list of artboards for multi-canvas support
/// - Per-artboard state isolation (layers, selection, viewport)
/// - Query helpers that delegate to artboards
///
/// ## Multi-Artboard Architecture (v2.0.0)
///
/// Starting in schema version 2:
/// - Documents contain artboards instead of direct layer access
/// - Each artboard has its own layers, selection, and viewport
/// - Legacy single-artboard documents are migrated to a default artboard
/// - Selection and viewport state are scoped per artboard
///
/// ## Snapshot Serialization
///
/// Documents are serialized to JSON snapshots that preserve:
/// - Schema version for migration support
/// - Artboard list with ordering (deterministic array serialization)
/// - Per-artboard layer stacks and state
/// - Object IDs and properties (stable across serialization)
/// - Per-artboard selection and viewport state
///
/// ## Examples
///
/// Create a multi-artboard document:
/// ```dart
/// final doc = Document(
///   id: 'doc-1',
///   title: 'Responsive Design',
///   artboards: [mobileArtboard, tabletArtboard, desktopArtboard],
/// );
/// ```
///
/// Query objects across artboards:
/// ```dart
/// final obj = doc.getObjectById('path-1');
/// final allObjs = doc.getAllObjects();
/// final artboard = doc.getArtboardById('artboard-1');
/// ```
///
/// Serialize to JSON:
/// ```dart
/// final json = doc.toJson();
/// final restored = Document.fromJson(json);
/// assert(doc == restored); // Deep equality
/// ```
@freezed
class Document with _$Document {
  const factory Document({
    /// Unique identifier for this document.
    required String id,

    /// Document title shown in the UI and file system.
    @Default('Untitled') String title,

    /// Schema version for serialization migrations.
    ///
    /// This version is stored in snapshots and used to perform schema
    /// migrations when loading documents saved with older versions.
    @Default(kDocumentSchemaVersion) int schemaVersion,

    /// Ordered list of artboards in this document.
    ///
    /// Each artboard is an independent canvas with its own layers,
    /// selection, and viewport state. Artboards are arranged spatially
    /// on an infinite canvas.
    @Default([]) List<Artboard> artboards,

    /// DEPRECATED: Legacy layers field for backward compatibility.
    ///
    /// This field exists only to support migration from schema v1 to v2.
    /// New code should use artboards instead. Will be removed in v3.
    @Deprecated('Use artboards instead. Exists for v1->v2 migration only.')
    @Default([])
    List<Layer>? layers,

    /// DEPRECATED: Legacy selection field for backward compatibility.
    ///
    /// This field exists only to support migration from schema v1 to v2.
    /// Selection state is now stored per-artboard. Will be removed in v3.
    @Deprecated('Use artboard.selection instead. Exists for v1->v2 migration only.')
    Selection? selection,

    /// DEPRECATED: Legacy viewport field for backward compatibility.
    ///
    /// This field exists only to support migration from schema v1 to v2.
    /// Viewport state is now stored per-artboard. Will be removed in v3.
    @Deprecated('Use artboard.viewport instead. Exists for v1->v2 migration only.')
    Viewport? viewport,
  }) = _Document;

  /// Private constructor for accessing methods on Freezed class.
  const Document._();

  /// Creates a Document from JSON.
  ///
  /// This factory handles deserialization from snapshot storage.
  /// Schema versioning and migrations are handled transparently.
  /// The schemaVersion field in JSON is preserved during round-trips.
  ///
  /// For v1 documents (legacy schema), this will create a default artboard
  /// from the layers/selection/viewport fields during migration.
  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);

  /// Finds an artboard by ID.
  ///
  /// Returns null if no artboard with the given ID exists.
  Artboard? getArtboardById(String artboardId) {
    try {
      return artboards.firstWhere((ab) => ab.id == artboardId);
    } catch (_) {
      return null;
    }
  }

  /// Returns all vector objects from all artboards and layers.
  ///
  /// Objects are returned in artboard order, then layer order within each
  /// artboard. This is useful for document-wide operations.
  List<VectorObject> getAllObjects() =>
      artboards.expand((artboard) => artboard.getAllObjects()).toList();

  /// Finds an object by ID across all artboards and layers.
  ///
  /// Returns null if no object with the given ID exists in any artboard.
  VectorObject? getObjectById(String objectId) {
    for (final artboard in artboards) {
      final obj = artboard.getObjectById(objectId);
      if (obj != null) return obj;
    }
    return null;
  }

  /// Finds the artboard containing the given object ID.
  ///
  /// Returns null if the object is not found in any artboard.
  Artboard? getArtboardContainingObject(String objectId) {
    for (final artboard in artboards) {
      if (artboard.getObjectById(objectId) != null) {
        return artboard;
      }
    }
    return null;
  }

  /// Finds the layer containing the given object ID.
  ///
  /// Returns null if the object is not found in any layer.
  /// Searches across all artboards.
  Layer? getLayerContainingObject(String objectId) {
    for (final artboard in artboards) {
      final layer = artboard.getLayerContainingObject(objectId);
      if (layer != null) return layer;
    }
    return null;
  }

  /// Returns objects at the given point for a specific artboard.
  ///
  /// Objects are returned in reverse rendering order (top-most first).
  /// This is useful for hit testing during selection within an artboard window.
  List<VectorObject> objectsAtPoint(Point point, String artboardId) {
    final artboard = getArtboardById(artboardId);
    if (artboard == null) return [];
    return artboard.objectsAtPoint(point);
  }

  /// Returns objects within the given bounds for a specific artboard.
  ///
  /// This is useful for marquee selection and viewport culling.
  List<VectorObject> objectsInBounds(Rectangle bounds, String artboardId) {
    final artboard = getArtboardById(artboardId);
    if (artboard == null) return [];
    return artboard.objectsInBounds(bounds);
  }

  /// Returns all selected objects across all artboards.
  ///
  /// Objects are returned in artboard order, then rendering order within
  /// each artboard. This is useful for multi-artboard copy/paste operations.
  List<VectorObject> getSelectedObjects() =>
      artboards.expand((ab) => ab.getSelectedObjects()).toList();

  /// Returns selected objects for a specific artboard.
  ///
  /// Returns empty list if artboard doesn't exist.
  List<VectorObject> getSelectedObjectsForArtboard(String artboardId) {
    final artboard = getArtboardById(artboardId);
    if (artboard == null) return [];
    return artboard.getSelectedObjects();
  }

  /// Returns true if the document has any unsaved changes.
  ///
  /// Note: This is a placeholder. In future iterations, this will be
  /// determined by comparing against the last saved snapshot.
  bool get hasUnsavedChanges => true;

  /// Returns true if the document is empty (no artboards or all artboards empty).
  bool get isEmpty =>
      artboards.isEmpty || artboards.every((artboard) => artboard.isEmpty);
}
