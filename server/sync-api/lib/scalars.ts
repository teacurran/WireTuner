import { GraphQLScalarType, Kind } from 'graphql';

/**
 * UUID scalar type
 * Validates RFC 4122 UUIDs
 */
export const UUIDScalar = new GraphQLScalarType({
  name: 'UUID',
  description: 'RFC 4122 UUID scalar type',

  serialize(value: unknown): string {
    if (typeof value !== 'string') {
      throw new Error('UUID must be a string');
    }
    if (!isValidUUID(value)) {
      throw new Error(`Invalid UUID: ${value}`);
    }
    return value;
  },

  parseValue(value: unknown): string {
    if (typeof value !== 'string') {
      throw new Error('UUID must be a string');
    }
    if (!isValidUUID(value)) {
      throw new Error(`Invalid UUID: ${value}`);
    }
    return value;
  },

  parseLiteral(ast): string {
    if (ast.kind !== Kind.STRING) {
      throw new Error('UUID must be a string');
    }
    if (!isValidUUID(ast.value)) {
      throw new Error(`Invalid UUID: ${ast.value}`);
    }
    return ast.value;
  },
});

/**
 * DateTime scalar type
 * ISO 8601 date-time strings
 */
export const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description: 'ISO 8601 DateTime scalar',

  serialize(value: unknown): string {
    if (value instanceof Date) {
      return value.toISOString();
    }
    if (typeof value === 'string') {
      return new Date(value).toISOString();
    }
    throw new Error('DateTime must be a Date or ISO 8601 string');
  },

  parseValue(value: unknown): Date {
    if (typeof value !== 'string') {
      throw new Error('DateTime must be an ISO 8601 string');
    }
    const date = new Date(value);
    if (isNaN(date.getTime())) {
      throw new Error(`Invalid DateTime: ${value}`);
    }
    return date;
  },

  parseLiteral(ast): Date {
    if (ast.kind !== Kind.STRING) {
      throw new Error('DateTime must be a string');
    }
    const date = new Date(ast.value);
    if (isNaN(date.getTime())) {
      throw new Error(`Invalid DateTime: ${ast.value}`);
    }
    return date;
  },
});

/**
 * Validate UUID format (RFC 4122)
 */
function isValidUUID(value: string): boolean {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}
