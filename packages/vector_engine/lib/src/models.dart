/// Immutable data models for vector graphics primitives.
///
/// This module will provide the core data structures for representing
/// vector graphics objects (paths, shapes, groups, documents).
library;

/// TODO: Implement vector graphics data models.
///
/// Future implementation will include:
/// - Path model with anchor points and Bezier control points
/// - Shape primitives (rectangle, ellipse, polygon, star)
/// - Group and layer models
/// - Document model with version and metadata
/// - Transformation matrices
class VectorModels {
  /// Creates an instance of the vector models utilities.
  const VectorModels();

  /// Returns the version of the models schema.
  String get schemaVersion => '1.0.0';
}
