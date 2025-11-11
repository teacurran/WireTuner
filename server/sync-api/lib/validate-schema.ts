#!/usr/bin/env node
/**
 * Validate GraphQL schema using graphql-js built-in validation
 * This provides more reliable validation than graphql-schema-linter
 */
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { buildSchema, validateSchema } from 'graphql';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const schemaPath = join(__dirname, '../../../api/schema.graphql');
const schemaSource = readFileSync(schemaPath, 'utf-8');

try {
  const schema = buildSchema(schemaSource);
  const errors = validateSchema(schema);

  if (errors.length > 0) {
    console.error('❌ Schema validation failed:');
    errors.forEach((error) => {
      console.error(`  - ${error.message}`);
    });
    process.exit(1);
  } else {
    console.log('✅ GraphQL schema is valid');
    console.log(`📄 Schema loaded from: ${schemaPath}`);
    console.log(`📊 Types defined: ${Object.keys(schema.getTypeMap()).filter(t => !t.startsWith('__')).length}`);
    process.exit(0);
  }
} catch (error) {
  console.error('❌ Schema parsing error:');
  console.error((error as Error).message);
  process.exit(1);
}
