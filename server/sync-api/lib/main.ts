import { createYoga } from 'graphql-yoga';
import { createServer } from 'http';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { makeExecutableSchema } from '@graphql-tools/schema';
import { createContext } from './context.js';
import { resolvers } from './resolvers/index.js';

// ES module __dirname equivalent
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Load GraphQL SDL schema from api/schema.graphql
 */
function loadSchema(): string {
  const schemaPath = join(__dirname, '../../../api/schema.graphql');
  return readFileSync(schemaPath, 'utf-8');
}

/**
 * Create executable GraphQL schema
 */
const schema = makeExecutableSchema({
  typeDefs: loadSchema(),
  resolvers,
});

/**
 * Create GraphQL Yoga server
 */
const yoga = createYoga({
  schema,
  context: createContext,
  graphiql: {
    title: 'WireTuner Sync API',
    defaultQuery: `# Welcome to WireTuner GraphQL API
#
# Example queries:
#
# query GetDocument {
#   documentSummary(id: "a3bb189e-8bf9-4bc6-9c8e-d3d0c2b3e9f1") {
#     id
#     name
#     artboards(first: 10) {
#       edges {
#         node {
#           id
#           name
#         }
#       }
#     }
#   }
# }
`,
  },
  cors: {
    origin: '*', // TODO: Configure production CORS policy
    credentials: true,
  },
  maskedErrors: false, // Show full errors in development
});

/**
 * Start HTTP server
 */
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 4000;
const server = createServer(yoga);

server.listen(PORT, () => {
  console.log(`🚀 WireTuner Sync API running at http://localhost:${PORT}/graphql`);
  console.log(`📊 GraphiQL interface available for interactive queries`);
  console.log(`🔍 Schema validation: npm run lint:schema`);
  console.log(`📡 Telemetry spec validation: npm run lint:telemetry`);
});

/**
 * Graceful shutdown
 */
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('\n🛑 SIGTERM received, shutting down...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});
