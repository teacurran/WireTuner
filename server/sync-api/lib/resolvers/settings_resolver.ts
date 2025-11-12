import { GraphQLContext } from '../context.js';

/**
 * Settings query and mutation resolvers
 */
export const settingsResolvers = {
  Query: {
    /**
     * Fetch user settings profile
     */
    settingsProfile: async (
      _parent: unknown,
      args: { userId: string },
      context: GraphQLContext
    ) => {
      const { userId } = args;

      // TODO: Query from SettingsProfile table once Prisma model is enhanced
      // For now, return mock data matching Section 3.7.4.5 DTO structure

      return {
        userId,
        samplingInterval: {
          effectiveValue: '100',
          source: 'DEFAULT',
          updatedAt: new Date(),
        },
        snapshotThreshold: {
          effectiveValue: '1000',
          source: 'DEFAULT',
          updatedAt: new Date(),
        },
        anchorVisibilityDefault: {
          effectiveValue: 'SELECTED',
          source: 'USER',
          updatedAt: new Date(),
        },
        telemetryEnabled: {
          effectiveValue: 'true',
          source: 'USER',
          updatedAt: new Date(),
        },
        gridSnapEnabled: {
          effectiveValue: 'true',
          source: 'DEFAULT',
          updatedAt: new Date(),
        },
        nudgeDistanceOverrides: {
          effectiveValue: '10',
          source: 'DEFAULT',
          updatedAt: new Date(),
        },
        pendingAdminOverrides: [],
      };
    },
  },

  Mutation: {
    /**
     * Update user settings profile
     */
    updateSettings: async (
      _parent: unknown,
      args: {
        userId: string;
        input: {
          samplingIntervalMs?: number;
          gridSnapScreenPx?: number;
          undoDepth?: number;
          anchorVisibilityMode?: string;
          telemetryEnabled?: boolean;
          nudgePreset?: number;
        };
      },
      context: GraphQLContext
    ) => {
      const { userId, input } = args;

      // TODO: Update SettingsProfile in database
      // For now, return mock updated settings with 'USER' source

      const now = new Date();

      return {
        userId,
        samplingInterval: {
          effectiveValue: input.samplingIntervalMs?.toString() ?? '100',
          source: input.samplingIntervalMs !== undefined ? 'USER' : 'DEFAULT',
          updatedAt: now,
        },
        snapshotThreshold: {
          effectiveValue: '1000',
          source: 'DEFAULT',
          updatedAt: now,
        },
        anchorVisibilityDefault: {
          effectiveValue: input.anchorVisibilityMode ?? 'SELECTED',
          source: input.anchorVisibilityMode !== undefined ? 'USER' : 'DEFAULT',
          updatedAt: now,
        },
        telemetryEnabled: {
          effectiveValue: input.telemetryEnabled?.toString() ?? 'true',
          source: input.telemetryEnabled !== undefined ? 'USER' : 'DEFAULT',
          updatedAt: now,
        },
        gridSnapEnabled: {
          effectiveValue: 'true',
          source: 'DEFAULT',
          updatedAt: now,
        },
        nudgeDistanceOverrides: {
          effectiveValue: input.nudgePreset?.toString() ?? '10',
          source: input.nudgePreset !== undefined ? 'USER' : 'DEFAULT',
          updatedAt: now,
        },
        pendingAdminOverrides: [],
      };
    },
  },
};
