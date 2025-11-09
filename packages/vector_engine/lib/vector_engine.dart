/// Vector graphics engine for WireTuner.
///
/// This package provides the core vector graphics functionality:
/// - Immutable data models for paths, shapes, and documents
/// - Geometry mathematics (Bezier curves, transformations, intersections)
/// - Hit testing for selection and manipulation
/// - Bounding box calculations
library vector_engine;

export 'src/models.dart';
export 'src/geometry.dart';
export 'src/hit_testing.dart';
