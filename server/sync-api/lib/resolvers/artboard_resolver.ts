import { GraphQLContext } from '../context.js';

/**
 * Artboard mutation resolvers
 */
export const artboardResolvers = {
  Mutation: {
    /**
     * Create a new artboard
     * Emits artboard.created event, schedules thumbnail job, updates caches
     */
    createArtboard: async (
      _parent: unknown,
      args: {
        input: {
          documentId: string;
          name: string;
          preset: string;
          bounds: { x: number; y: number; width: number; height: number };
          backgroundColor: { r: number; g: number; b: number; a: number };
          viewportState?: { zoom: number; panOffsetX: number; panOffsetY: number };
          selectionState?: { objectIds: string[] };
          zOrder?: number;
          clientRequestId?: string;
          featureFlags?: string[];
        };
      },
      context: GraphQLContext
    ) => {
      const { input } = args;

      // Validate bounds are within 100-100,000 px range per contract
      const warnings: Array<{ code: string; message: string; remediation?: string }> = [];

      if (input.bounds.width < 100 || input.bounds.width > 100000) {
        warnings.push({
          code: 'BOUNDS_OUT_OF_RANGE',
          message: `Width ${input.bounds.width} is outside valid range 100-100000 px`,
          remediation: 'Adjust artboard width to be within acceptable bounds',
        });
      }

      if (input.bounds.height < 100 || input.bounds.height > 100000) {
        warnings.push({
          code: 'BOUNDS_OUT_OF_RANGE',
          message: `Height ${input.bounds.height} is outside valid range 100-100000 px`,
          remediation: 'Adjust artboard height to be within acceptable bounds',
        });
      }

      // Validate name length ≤100 characters
      if (input.name.length > 100) {
        warnings.push({
          code: 'NAME_TOO_LONG',
          message: 'Artboard name exceeds 100 character limit',
          remediation: 'Shorten artboard name',
        });
      }

      // Verify document exists
      const document = await context.prisma.document.findUnique({
        where: { id: input.documentId },
      });

      if (!document) {
        throw new Error(`Document ${input.documentId} not found`);
      }

      // Generate operation ID for undo tracking
      const operationId = crypto.randomUUID();
      const artboardId = crypto.randomUUID();

      // TODO: Insert artboard into database once Artboard Prisma model is added
      // For now, return mock response matching DTO structure from Section 3.7.4.1

      // Mock: Emit artboard.created event to EventStoreService
      // await context.prisma.event.create({ ... });

      // Mock: Schedule thumbnail generation job
      const thumbnailStatus = {
        state: 'queued',
        lastUpdatedAt: new Date(),
      };

      return {
        artboard: {
          id: artboardId,
          documentId: input.documentId,
          name: input.name,
          bounds: input.bounds,
          backgroundColor: input.backgroundColor,
          zOrder: input.zOrder ?? 0,
          preset: input.preset,
          viewportState: input.viewportState ?? null,
          selectionStateDigest: null,
          thumbnailRef: null,
          layers: [],
        },
        operationId,
        thumbnailStatus,
        warnings,
        snapshotSequence: document.snapshotSequence + 1,
      };
    },
  },
};
