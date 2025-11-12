# core

**WireTuner Core Domain Package** - Domain Layer

## Overview

This package contains the Domain layer of the WireTuner application, representing the pure business logic and immutable domain models following Clean Architecture principles.

## Responsibilities

- **Domain Models:** Immutable data classes for Document, Artboard, Layer, VectorObject, etc.
- **Event Definitions:** Event sourcing primitives and event schema
- **Business Logic:** Core application rules and invariants
- **Geometric Utilities:** Vector math, path calculations, hit testing algorithms

## Architecture Layer

**Position:** Domain (innermost layer - the core)

**Dependencies:**
- **NONE** - This package has zero dependencies on other application packages
- Only external dependencies: `uuid`, `vector_math`, `freezed_annotation`

**Direction:** All other layers depend on this layer. This layer depends on nothing.

## Clean Architecture Boundaries

```
Infrastructure → Application → Domain (this package)
                               ↑
Presentation ──────────────────┘
```

## Architectural Constraints

Per specification Section 7.2:

1. **Immutability:** All domain models **MUST** be immutable
   - Use Freezed `@freezed` annotation for all models
   - No mutable fields allowed

2. **No Flutter Dependencies:** Pure Dart only
   - Cannot import `package:flutter`
   - Ensures domain logic is framework-independent

3. **No I/O Operations:** Pure business logic only
   - No file operations
   - No network calls
   - No database access

4. **Pure Functions:** No side effects
   - Deterministic calculations only
   - Testable without mocks

## Code Generation

This package uses Freezed for code generation:

```bash
# Generate immutable models
melos run build:runner --scope=core

# Or manually
cd packages/core
dart run build_runner build --delete-conflicting-outputs
```

## Status

**Current Phase:** Placeholder package created in Iteration I1.

**Future Development:**
- **Iteration I2:** Implement core domain models (Document, Artboard, Layer, Path, Shape)
- **Iteration I3:** Add event schema and tool framework interfaces
- **Iteration I4:** Extend event definitions for undo/redo operations

## Development

This package is managed as part of the WireTuner melos workspace.

```bash
# Install dependencies
melos bootstrap

# Run tests
melos run test --scope=core

# Analyze code
melos run analyze --scope=core
```

For complete workspace commands, see the [main README](../../README.md#workspace-commands).
