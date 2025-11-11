import { PrismaClient } from '@prisma/client';

/**
 * GraphQL resolver context
 * Contains authenticated user info, Prisma client, and request metadata
 */
export interface GraphQLContext {
  /** Prisma database client */
  prisma: PrismaClient;

  /** Authenticated user ID (from JWT) */
  userId?: string;

  /** JWT payload (stub for future auth implementation) */
  jwt?: {
    sub: string;
    email: string;
    roles: string[];
  };

  /** Request metadata */
  request: {
    /** Client IP address */
    ip: string;
    /** User agent string */
    userAgent: string;
    /** Request ID for correlation */
    requestId: string;
  };
}

/**
 * Create GraphQL context for each request
 */
export async function createContext(): Promise<GraphQLContext> {
  const prisma = new PrismaClient();

  return {
    prisma,
    userId: undefined, // TODO: Extract from JWT in Authorization header
    jwt: undefined,
    request: {
      ip: '127.0.0.1',
      userAgent: 'unknown',
      requestId: crypto.randomUUID(),
    },
  };
}
