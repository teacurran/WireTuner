# app

**WireTuner Application Package** - Presentation Layer

## Overview

This package contains the Presentation layer of the WireTuner application, following Clean Architecture principles.

## Responsibilities

- **UI Components:** Flutter widgets, pages, and navigation
- **Rendering Pipeline:** CustomPainter implementations for vector graphics rendering
- **User Interaction:** Tool interaction handling, keyboard shortcuts, pointer events
- **State Management:** Provider-based UI state reactivity

## Architecture Layer

**Position:** Presentation (outermost layer)

**Dependencies:**
- `core` - Domain models, events, business logic (required)
- `infrastructure` - I/O services, persistence (required)

**Direction:** This layer depends on inner layers but should never be depended upon by them.

## Clean Architecture Boundaries

```
Presentation (this package)
    ↓ depends on
Application
    ↓ depends on
Domain (core)
```

## Status

**Current Phase:** Placeholder package created in Iteration I1.

**Future Development:**
- Iteration I2: Vector models and event foundations
- Iteration I3: Tool framework implementation
- Iteration I4: Undo/redo UI integration
- Iteration I5: Import/export workflows

## Development

This package is managed as part of the WireTuner melos workspace.

```bash
# Install dependencies
melos bootstrap

# Run tests
melos run test --scope=app

# Analyze code
melos run analyze --scope=app
```

For complete workspace commands, see the [main README](../../README.md#workspace-commands).
