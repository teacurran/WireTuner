# WireTuner Collaboration Gateway

Real-time collaboration backend service implementing Operational Transform (OT) for conflict-free concurrent editing in WireTuner.

## Overview

The Collaboration Gateway enables multiple users to simultaneously edit the same WireTuner document with automatic conflict resolution. It implements the OT strategy defined in [ADR-0002](../../docs/adr/ADR-0002-ot-strategy.md).

### Key Features

- **WebSocket-based real-time operation streaming**
- **Operational Transform (OT) for conflict resolution**
- **JWT authentication and session management**
- **Redis pub/sub for horizontal scaling**
- **Presence tracking** (cursors, selections, user status)
- **Automatic idle timeout** (5 minutes)
- **Rate limiting** (300 ops/minute per client)
- **Concurrency limits** (max 10 concurrent editors per document)

### Performance Targets

- **P99 Latency:** <100ms for transform + broadcast
- **Concurrent Editors:** Up to 10 simultaneous editors per document
- **Throughput:** 300 operations/minute per client
- **Idle Timeout:** 5 minutes of inactivity

## Architecture

### Components

```
┌─────────────────────────────────────────────────────┐
│           Collaboration Gateway                      │
│                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  WebSocket  │  │ OT Transform │  │   Redis   │ │
│  │   Handler   │──│    Engine    │──│  Pub/Sub  │ │
│  └─────────────┘  └──────────────┘  └───────────┘ │
│         │                  │                │       │
│         │                  │                │       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Session   │  │     Auth     │  │  Presence │ │
│  │  Management │  │  Middleware  │  │  Tracker  │ │
│  └─────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
```

### Data Flow

1. **Client connects** → JWT validation → Session created
2. **Client submits operation** → OT transformation → Broadcast to all clients
3. **Operation persisted** → Redis pub/sub → Other gateway instances notified
4. **Idle check** → Sessions inactive >5min disconnected

## Quick Start

### Installation

```bash
# From WireTuner root
melos bootstrap

# Install dependencies
cd server/collaboration-gateway
dart pub get
```

### Running Tests

```bash
# Run all tests
dart test

# Run specific test suite
dart test test/ot_transform_test.dart
dart test test/websocket_session_test.dart
```

### Development

This package is managed as part of the WireTuner melos workspace.

```bash
# Run tests
melos run test --scope=collaboration_gateway

# Analyze code
melos run analyze --scope=collaboration_gateway
```

## API Reference

### WebSocket Protocol

#### Connection

```
ws://localhost:8080/ws?documentId=<document-id>
Authorization: Bearer <jwt-token>
```

#### Message Types

See full protocol specification in the [API Documentation](#websocket-protocol) section.

Key message types:
- `operationSubmit` - Client submits an operation
- `operationBroadcast` - Server broadcasts transformed operation
- `operationAck` - Server acknowledges operation receipt
- `cursorUpdate` - Presence: cursor position
- `selectionUpdate` - Presence: object selection
- `userJoined` / `userLeft` - Presence notifications
- `heartbeat` - Keep-alive ping

## OT Transformation Rules

The transformation logic implements convergence (TP1), causality preservation (TP2), and intent preservation as specified in ADR-0002.

### Key Transform Behaviors

| Operation A | Operation B | Result |
|------------|-------------|--------|
| Insert@5 | Insert@5 | Index adjusted by tiebreaker (userId) |
| Insert | Delete | No conflict |
| Delete | Delete (same object) | Second becomes no-op |
| Move | Delete (same object) | Move becomes no-op |
| Move | Move (same object) | Deltas combined |
| Modify | Delete (same object) | Modify becomes no-op |
| Modify | Modify (same property) | Last-Write-Wins by timestamp |
| ModifyAnchor | Delete (same path) | ModifyAnchor becomes no-op |

## Testing

### Test Coverage

- **OT Transformation Tests** (`test/ot_transform_test.dart`)
  - All operation pair combinations
  - Convergence property (TP1) verification
  - Intent preservation validation

- **WebSocket Session Tests** (`test/websocket_session_test.dart`)
  - Session lifecycle
  - Room management
  - Concurrency limits
  - Idle timeout
  - Authentication

### Test Example

```dart
test('Move-Delete: moving deleted object becomes no-op', () {
  final move = OTOperation.move(
    operationId: 'op1',
    userId: 'user1',
    sessionId: 'session1',
    localSequence: 1,
    serverSequence: 0,
    targetId: 'obj1',
    deltaX: 100,
    deltaY: 200,
    timestamp: 1000,
  );

  final delete = OTOperation.delete(
    operationId: 'op2',
    userId: 'user2',
    sessionId: 'session2',
    localSequence: 1,
    serverSequence: 0,
    targetId: 'obj1',
    timestamp: 1000,
  );

  final result = transform(move, delete);
  expect(result, isA<NoOpOperation>());
});
```

## Status

**Current Phase:** MVP implementation completed in Iteration I4.

**Deliverables:**
- ✅ WebSocket server with OT transformation
- ✅ OT transformer library covering all operation types
- ✅ JWT authentication middleware
- ✅ Redis pub/sub integration
- ✅ CollaborationClient for Flutter integration
- ✅ Comprehensive test coverage

## References

- [ADR-0002: OT Strategy](../../docs/adr/ADR-0002-ot-strategy.md)
- [Architecture Blueprint](../../.codemachine/artifacts/architecture/01_Blueprint_Foundation.md)
- [Operational Transform Paper](http://www.codecommit.com/blog/java/understanding-and-applying-operational-transformation)
