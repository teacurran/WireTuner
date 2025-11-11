import { GraphQLContext } from '../context.js';

/**
 * Presence subscription resolvers
 * Fallback for when WebSocket firewall policies prohibit raw connections
 */
export const presenceResolvers = {
  Subscription: {
    /**
     * Subscribe to document presence updates
     * Streams user activity, cursor position, selection state per Section 3.7.4.6
     */
    documentPresence: {
      subscribe: async function* (
        _parent: unknown,
        args: {
          documentId: string;
          artboardFilter?: string[];
          cursorSamplingMs?: number;
        },
        context: GraphQLContext
      ) {
        const { documentId, artboardFilter, cursorSamplingMs = 100 } = args;

        // TODO: Hook into real collaboration gateway pub/sub (Redis, etc.)
        // For now, emit mock presence updates at sampling interval

        const mockUser = {
          id: crypto.randomUUID(),
          email: 'collaborator@example.com',
          displayName: 'Mock Collaborator',
          avatarUrl: null,
          roles: ['user'],
          platform: 'MACOS',
          createdAt: new Date(),
          lastActiveAt: new Date(),
          telemetryOptIn: true,
          featureFlagOverrides: [],
        };

        // Emit presence frames every cursorSamplingMs
        let sequence = 0;
        while (true) {
          await new Promise((resolve) => setTimeout(resolve, cursorSamplingMs));

          sequence++;

          yield {
            documentPresence: {
              user: mockUser,
              activity: 'EDITING',
              selectedArtboardIds: artboardFilter ?? [],
              selectionBounds: null,
              cursor: {
                screenX: Math.random() * 1920,
                screenY: Math.random() * 1080,
                tool: 'pen',
                pressure: Math.random(),
              },
              latencyMs: 50,
              lastEventSequence: sequence,
              undoDepthRemaining: 10,
              featureFlags: [],
              idleReason: null,
              deviceInfo: {
                platform: 'MACOS',
                appVersion: '0.1.0',
              },
              protocolVersion: '1.0',
            },
          };

          // Stop after 10 updates for demonstration (real implementation would run indefinitely)
          if (sequence >= 10) {
            break;
          }
        }
      },
    },
  },
};
