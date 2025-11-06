# T012: Document Model

## Status
- **Phase**: 2 - Vector Data Model
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T010, T011

## Overview
Create the Document model that contains all objects, layers, and metadata.

## Objectives
- Define Document class
- Support layers for organization
- Manage object hierarchy
- Track selection state
- Serialize/deserialize document state

## Implementation

### Document Model (lib/models/document/document.dart)
```dart
class Document {
  final String id;
  final DocumentMetadata metadata;
  final List<Layer> layers;
  final Artboard artboard;

  const Document({
    required this.id,
    required this.metadata,
    required this.layers,
    required this.artboard,
  });

  List<VectorObject> get allObjects {
    return layers.expand((layer) => layer.objects).toList();
  }

  VectorObject? getObject(String id) {
    for (final layer in layers) {
      final obj = layer.objects.firstWhere((o) => o.id == id, orElse: () => null);
      if (obj != null) return obj;
    }
    return null;
  }

  Document withObjectUpdated(VectorObject updated) {
    // Immutably update object
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'metadata': metadata.toJson(),
    'layers': layers.map((l) => l.toJson()).toList(),
    'artboard': artboard.toJson(),
  };

  factory Document.fromJson(Map<String, dynamic> json) {
    // Deserialize
  }

  static Document empty() => Document(
    id: const Uuid().v4(),
    metadata: DocumentMetadata.empty(),
    layers: [Layer.default()],
    artboard: Artboard.default(),
  );
}

class DocumentMetadata {
  final String name;
  final String author;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const DocumentMetadata({
    required this.name,
    required this.author,
    required this.createdAt,
    required this.modifiedAt,
  });

  static DocumentMetadata empty() => DocumentMetadata(
    name: 'Untitled',
    author: 'Unknown',
    createdAt: DateTime.now(),
    modifiedAt: DateTime.now(),
  );
}

class Layer {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final List<VectorObject> objects;

  const Layer({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    required this.objects,
  });

  static Layer default() => Layer(
    id: const Uuid().v4(),
    name: 'Layer 1',
    objects: [],
  );
}

class Artboard {
  final Rect bounds;
  final Color backgroundColor;

  const Artboard({
    required this.bounds,
    this.backgroundColor = Colors.white,
  });

  static Artboard default() => const Artboard(
    bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  );
}

abstract class VectorObject {
  String get id;
  Transform2D get transform;
  PathStyle get style;
}

class PathObject implements VectorObject {
  final VectorPath path;

  const PathObject(this.path);

  @override
  String get id => path.id;

  @override
  Transform2D get transform => path.transform;

  @override
  PathStyle get style => path.style;
}

class ShapeObject implements VectorObject {
  final Shape shape;

  const ShapeObject(this.shape);

  @override
  String get id => shape.id;

  @override
  Transform2D get transform => shape.transform;

  @override
  PathStyle get style => shape.style;
}
```

## Success Criteria

### Automated Verification
- [ ] Can create empty document
- [ ] Can add objects to layers
- [ ] Can find object by ID
- [ ] Can serialize/deserialize document
- [ ] Document state is immutable

### Manual Verification
- [ ] Document structure makes sense
- [ ] Can model complex multi-layer documents

## References
- T010: Path Data Model
- T011: Shape Data Model
