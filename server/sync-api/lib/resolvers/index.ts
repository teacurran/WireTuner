import { documentResolvers } from './document_resolver.js';
import { artboardResolvers } from './artboard_resolver.js';
import { settingsResolvers } from './settings_resolver.js';
import { presenceResolvers } from './presence_resolver.js';
import { UUIDScalar, DateTimeScalar } from '../scalars.js';

/**
 * Merged resolver map for GraphQL Yoga
 * Combines all domain resolvers and custom scalars
 */
export const resolvers = {
  // Custom scalars
  UUID: UUIDScalar,
  DateTime: DateTimeScalar,

  // Query resolvers
  Query: {
    ...documentResolvers.Query,
    ...settingsResolvers.Query,
  },

  // Mutation resolvers
  Mutation: {
    ...artboardResolvers.Mutation,
    ...settingsResolvers.Mutation,
  },

  // Subscription resolvers
  Subscription: {
    ...presenceResolvers.Subscription,
  },
};
