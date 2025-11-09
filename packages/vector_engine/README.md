# vector_engine

Vector graphics engine for WireTuner.

## Overview

This package provides the core vector graphics functionality including data models, geometry mathematics, and hit testing.

## Status

**Iteration I1**: Placeholder package created. Implementation planned for future iterations.

## Planned Features

- **Immutable Data Models**: Paths, shapes, groups, and documents
- **Geometry Mathematics**: Bezier curves, transformations, intersections
- **Hit Testing**: Selection and manipulation support
- **Bounding Box Calculations**: Performance optimizations

## Architecture

The vector engine provides:
- Pure Dart implementation (no Flutter dependencies)
- Immutable data structures for functional programming
- Precise geometric calculations with configurable tolerance
- Efficient hit testing with spatial optimization

## Usage

```dart
import 'package:vector_engine/vector_engine.dart';

const models = VectorModels();
const geometry = Geometry();
const hitTesting = HitTesting();
```

## Development

This package is part of the WireTuner melos workspace. See the root README for workspace commands.
