# infrastructure

**WireTuner Infrastructure Package** - Infrastructure Layer

## Overview

This package contains the Infrastructure layer of the WireTuner application, handling all I/O operations, persistence, and external service integrations following Clean Architecture principles.

## Responsibilities

- **Event Store:** SQLite-based event persistence and snapshot management
- **File I/O:** .wiretuner file format handling (save/load operations)
- **Import Services:** AI and SVG file import
- **Export Services:** SVG and PDF export
- **Persistence:** Database connection management, migrations, ACID guarantees

## Architecture Layer

**Position:** Infrastructure

**Dependencies:**
- `core` - Domain models and event definitions (required)

**Direction:** This layer implements interfaces defined by inner layers and provides concrete I/O implementations.

## Clean Architecture Boundaries

```
Presentation
    ↓
Application
    ↓
Domain (core) ← Infrastructure (this package)
```

Infrastructure sits alongside Application but both depend on the Domain (core) layer.

## Technology Stack

Per specification Section 7.1:

- **Database:** SQLite 3.x via `sqflite_common_ffi`
- **SVG Parsing:** `xml` package
- **PDF Generation:** `pdf` package (pure Dart, cross-platform)
- **File System:** `path_provider` for platform-specific directories

## Event Sourcing Implementation

This package provides the concrete implementation of:

- **Event Store:** Append-only event log in SQLite
- **Snapshot Manager:** Periodic snapshots every 1,000 events
- **Event Replayer:** Document reconstruction from events
- **Sampling Service:** 50ms sampling for high-frequency events

## Status

**Current Phase:** Placeholder package created in Iteration I1.

**Future Development:**
- **Iteration I2:** Implement event store and snapshot services
- **Iteration I5:** Add AI/SVG import and SVG/PDF export

## Development

This package is managed as part of the WireTuner melos workspace.

```bash
# Install dependencies
melos bootstrap

# Run tests
melos run test --scope=infrastructure

# Analyze code
melos run analyze --scope=infrastructure
```

For complete workspace commands, see the [main README](../../README.md#workspace-commands).
