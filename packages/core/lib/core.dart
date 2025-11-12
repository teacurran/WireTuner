/// WireTuner Core Domain Package (Domain Layer)
///
/// This package contains the pure business logic and domain models of the
/// WireTuner application following Clean Architecture principles.
///
/// **Responsibilities:**
/// - Immutable domain models (Document, Artboard, Layer, VectorObject)
/// - Event definitions (event sourcing primitives)
/// - Business logic and invariants
/// - Geometric calculations and vector math utilities
///
/// **Dependencies:**
/// - NONE (this is the innermost layer - no dependencies on other packages)
/// - Only external dependencies: uuid, vector_math, freezed annotations
///
/// **Architecture Layer:** Domain (core/innermost layer)
///
/// **Architectural Constraints:**
/// 1. All models MUST be immutable (use Freezed `@freezed` annotation)
/// 2. No Flutter dependencies allowed
/// 3. No I/O operations (file, network, database)
/// 4. Pure functions only - no side effects
library core;

// Thumbnail Worker (Background Processing)
export 'thumbnail/thumbnail_worker.dart';

/// Placeholder export to satisfy pub requirements.
/// Actual domain models will be added in Iteration I2.
class CorePlaceholder {
  /// Constructor
  const CorePlaceholder();
}
