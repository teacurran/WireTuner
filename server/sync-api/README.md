# WireTuner Sync API

GraphQL/REST metadata and snapshot exchange service for WireTuner.

## Overview

The Sync API provides:
- **GraphQL API** for document metadata, artboard CRUD, settings, and presence
- **REST API** for telemetry ingestion and export artifact downloads
- **Event-sourced** persistence with PostgreSQL via Prisma
- **Real-time subscriptions** for collaborative presence (fallback for WebSocket restrictions)

## Architecture

```
api/
├── schema.graphql              # GraphQL SDL schema
├── telemetry.yaml              # OpenAPI 3.1 telemetry spec
└── examples/
    ├── queries.graphql         # Sample queries
    ├── mutations.graphql       # Sample mutations
    └── subscriptions.graphql   # Sample subscriptions

server/sync-api/
├── lib/
│   ├── main.ts                 # Server entrypoint
│   ├── context.ts              # GraphQL context factory
│   ├── scalars.ts              # Custom UUID/DateTime scalars
│   └── resolvers/
│       ├── document_resolver.ts
│       ├── artboard_resolver.ts
│       ├── settings_resolver.ts
│       └── presence_resolver.ts
└── prisma/
    └── schema.prisma           # Database schema
```

## Getting Started

### Prerequisites

- Node.js 20+
- npm or pnpm

### Installation

```bash
cd server/sync-api
npm install
```

### Database Setup

```bash
# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:migrate:dev
```

### Development Server

```bash
# Start GraphQL Yoga server with hot reload
npm run dev
```

The server will start at `http://localhost:4000/graphql` with GraphiQL playground.

## API Documentation

### GraphQL Schema

The schema is defined in [`api/schema.graphql`](../../api/schema.graphql) and includes:

- **Queries:**
  - `documentSummary(id)` - Fetch document with artboards, collaboration status, health
  - `settingsProfile(userId)` - Fetch user settings with effective values and sources

- **Mutations:**
  - `createArtboard(input)` - Create artboard with bounds, preset, background color
  - `updateSettings(userId, input)` - Update user settings

- **Subscriptions:**
  - `documentPresence(documentId)` - Real-time presence updates for collaborators

### REST Endpoints

Defined in [`api/telemetry.yaml`](../../api/telemetry.yaml):

- `POST /telemetry/perf-sample` - Ingest performance metrics (FPS, latency, etc.)
- `POST /telemetry/replay-inconsistency` - Report event replay state hash mismatches
- `GET /exports/{jobId}` - Download export artifacts (PDF, SVG, JSON)

### Sample Queries

See [`api/examples/`](../../api/examples/) for fully documented query/mutation/subscription examples.

#### Example: Fetch Document Summary

```graphql
query GetDocumentSummary {
  documentSummary(id: "a3bb189e-8bf9-4bc6-9c8e-d3d0c2b3e9f1") {
    id
    name
    artboards(first: 10) {
      edges {
        node {
          id
          name
          bounds { x y width height }
          backgroundColor { r g b a }
        }
      }
    }
    health {
      sqliteIntegrity
      diskUsageBytes
    }
  }
}
```

#### Example: Create Artboard

```graphql
mutation CreateArtboard {
  createArtboard(input: {
    documentId: "a3bb189e-8bf9-4bc6-9c8e-d3d0c2b3e9f1"
    name: "Main Screen"
    preset: IPHONE_14_PRO
    bounds: { x: 0, y: 0, width: 1179, height: 2556 }
    backgroundColor: { r: 1.0, g: 1.0, b: 1.0, a: 1.0 }
  }) {
    artboard { id name }
    operationId
    snapshotSequence
  }
}
```

## Validation & Quality Gates

### GraphQL Schema Validation

```bash
npm run lint:schema
```

Validates SDL syntax, type definitions, and schema structure using GraphQL.js built-in validation.

### OpenAPI Telemetry Spec Validation

```bash
npm run lint:telemetry
```

Validates OpenAPI spec using Spectral with OAS 3.1 ruleset.

### Run All Validators

```bash
npm run lint
```

Both validators must pass for CI/CD pipeline approval.

## Contract Alignment

The API implementation follows **Section 3.7** (API Design & Communication) and **Section 5.0** (Contract) from the blueprint:

- **DTO Shapes:** GraphQL types mirror exact field names, nullability, and descriptions from Section 3.7.4
- **Performance:** `documentSummary` must resolve <100ms for docs ≤10K events
- **Pagination:** Artboards use Relay cursor pagination per contract
- **Security:** JWT authentication headers expected (stubbed for now)
- **Versioning:** `protocolVersion` included in subscription payloads

## Implementation Status

### ✅ Completed

- GraphQL SDL schema with 50+ types
- Resolver stubs for document, artboard, settings, presence
- OpenAPI telemetry spec with 3 endpoints
- Custom UUID/DateTime scalars
- Schema validation pipeline
- Sample query/mutation/subscription documentation

### 🚧 In Progress (Future Tasks)

- Artboard/Layer/VectorObject Prisma models (currently mocked in resolvers)
- Real Prisma data fetching (stubs return mock data)
- JWT authentication middleware
- WebSocket collaboration gateway integration
- Redis pub/sub for presence subscriptions
- Thumbnail generation job scheduling
- Event emission to EventStoreService

## Testing

```bash
# Run tests (placeholder)
npm test
```

Manual testing via GraphiQL:
1. Start server: `npm run dev`
2. Open http://localhost:4000/graphql
3. Execute sample queries from `api/examples/`

## Performance

- **Target:** documentSummary <100ms for docs ≤10K events (NFR-PERF-001)
- **Current:** Stub implementation, actual performance TBD after Prisma integration
- **Optimization:** Use DataLoader for N+1 prevention, Prisma select projections

## Security

- **Authentication:** JWT bearer tokens (middleware stubbed)
- **Authorization:** Role-based access control (RBAC) planned
- **Rate Limiting:** Telemetry endpoints enforce per-device quotas
- **TLS:** HTTPS-only in production (NFR-SEC)

## Deployment

```bash
# Build for production
npm run build

# Start production server
npm start
```

Environment variables:
- `PORT` - Server port (default: 4000)
- `DATABASE_URL` - PostgreSQL connection string (Prisma)
- `NODE_ENV` - Environment (development|production)

## Troubleshooting

### Schema Validation Fails

Ensure SDL syntax is correct - scalar descriptions must use `#` comments, not `"""` strings.

### Spectral Lint Errors

Check that `.spectral.yml` extends `spectral:oas` and rules exist in base ruleset.

### Prisma Client Errors

Run `npm run prisma:generate` after schema changes.

## References

- [GraphQL Yoga Docs](https://the-guild.dev/graphql/yoga-server/docs)
- [Prisma Client API](https://www.prisma.io/docs/reference/api-reference/prisma-client-reference)
- [OpenAPI 3.1 Spec](https://spec.openapis.org/oas/v3.1.0)
- [Spectral OpenAPI Linting](https://stoplight.io/open-source/spectral)

## License

Proprietary - WireTuner Project
