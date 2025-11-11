import { GraphQLContext } from '../context.js';

/**
 * Document query resolvers
 */
export const documentResolvers = {
  Query: {
    /**
     * Fetch document summary with optional artboards and snapshots
     * Must resolve in <100ms for docs ≤10K events per contract
     */
    documentSummary: async (
      _parent: unknown,
      args: {
        id: string;
        includeArtboards?: boolean;
        includeSnapshots?: boolean;
        artboardLimit?: number;
      },
      context: GraphQLContext
    ) => {
      const { id, includeArtboards = true, includeSnapshots = false, artboardLimit = 50 } = args;

      // Query document from Prisma
      const document = await context.prisma.document.findUnique({
        where: { id },
        include: {
          // Include related entities as needed
          events: includeSnapshots ? { take: 10 } : false,
        },
      });

      if (!document) {
        return null;
      }

      // Mock data for fields not yet in Prisma schema
      // TODO: Replace with actual Prisma queries once Artboard/Layer models are added
      return {
        id: document.id,
        name: document.name,
        author: {
          id: document.authorId,
          email: 'user@example.com',
          displayName: 'Mock User',
          avatarUrl: null,
          roles: ['user'],
          platform: 'MACOS',
          createdAt: new Date(),
          lastActiveAt: new Date(),
          telemetryOptIn: true,
          featureFlagOverrides: [],
        },
        fileFormatVersion: document.fileFormatVersion,
        metadata: {
          anchorVisibilityMode: (document.metadata as any)?.anchorVisibilityMode || 'SELECTED',
          samplingPreset: (document.metadata as any)?.samplingPreset || 'default',
          platform: (document.metadata as any)?.platform || 'MACOS',
        },
        createdAt: document.createdAt,
        modifiedAt: document.modifiedAt,
        artboardIds: [], // TODO: Query from Artboard table
        snapshotSequence: document.snapshotSequence,
        eventCount: document.eventCount,
        undoDepthLimit: 100, // Default from contract
        artboards: async () => ({
          edges: [], // TODO: Implement artboard pagination
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
          totalCount: 0,
        }),
        collaborationStatus: {
          active: false,
          participants: [],
          otBaselineSequence: 0,
        },
        performanceHints: {
          recommendedSnapshotThreshold: 1000,
          recommendedSamplingInterval: 100,
        },
        health: {
          sqliteIntegrity: 'ok',
          pendingMigrations: 0,
          diskUsageBytes: 0,
        },
        featureFlags: [],
        lastManualSaveAt: null,
        lastAutoSaveAt: null,
      };
    },
  },
};
