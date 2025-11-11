/// Vector graphics engine for WireTuner.
///
/// This package provides the core vector graphics functionality:
/// - Immutable data models for paths, shapes, and documents
/// - Geometry mathematics (Bezier curves, transformations, intersections)
/// - Hit testing for selection and manipulation
/// - Bounding box calculations
///
/// ## Core Geometry Primitives
///
/// The geometry module provides:
/// - [Point]: 2D points with vector arithmetic
/// - [AnchorPoint]: Path vertices with Bezier control handles
/// - [Segment]: Curve segments (line, Bezier, arc)
/// - [Path]: Composite curves made of anchors and segments
/// - [Shape]: Parametric shapes (rectangle, ellipse, polygon, star)
/// - [Bounds]: Axis-aligned bounding boxes
///
/// ## Usage
///
/// ```dart
/// import 'package:vector_engine/vector_engine.dart';
///
/// // Create a simple path
/// final path = Path.line(
///   start: Point(x: 0, y: 0),
///   end: Point(x: 100, y: 100),
/// );
///
/// // Create a parametric shape
/// final rect = Shape.rectangle(
///   center: Point(x: 100, y: 100),
///   width: 200,
///   height: 150,
///   cornerRadius: 10,
/// );
///
/// // Convert shape to path
/// final rectPath = rect.toPath();
/// ```
library vector_engine;

export 'src/models.dart';
export 'src/geometry.dart';
export 'src/hit_testing.dart';
