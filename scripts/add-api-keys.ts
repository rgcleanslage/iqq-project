#!/usr/bin/env ts-node
/**
 * Script to add API keys to DynamoDB
 * 
 * Usage:
 *   ts-node scripts/add-api-keys.ts
 * 
 * This script adds API key records to the iqq-config-dev DynamoDB table.
 * API keys are stored with PK='API_KEY' and SK=<api-key-value>
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import * as crypto from 'crypto';

const REGION = 'us-east-1';
const TABLE_NAME = 'iqq-config-dev';

const dynamoClient = new DynamoDBClient({ region: REGION });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

// Generate a secure random API key
function generateApiKey(): string {
  return crypto.randomBytes(32).toString('base64url');
}

// Add an API key to DynamoDB
async function addApiKey(apiKey: string, clientId: string, name: string, status: 'active' | 'inactive' = 'active') {
  try {
    await docClient.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        PK: 'API_KEY',
        SK: apiKey,
        apiKey,
        clientId,
        name,
        status,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    }));
    console.log(`✓ Added API key for ${name} (${clientId})`);
    console.log(`  API Key: ${apiKey}`);
  } catch (error) {
    console.error(`✗ Failed to add API key for ${name}:`, error);
    throw error;
  }
}

async function main() {
  console.log('Adding API keys to DynamoDB...\n');

  // Generate new API keys for different clients
  const apiKeys = [
    {
      apiKey: generateApiKey(),
      clientId: 'default',
      name: 'Default API Key',
      status: 'active' as const,
    },
    {
      apiKey: generateApiKey(),
      clientId: 'partner-a',
      name: 'Partner A',
      status: 'active' as const,
    },
    {
      apiKey: generateApiKey(),
      clientId: 'partner-b',
      name: 'Partner B',
      status: 'active' as const,
    },
  ];

  for (const key of apiKeys) {
    await addApiKey(key.apiKey, key.clientId, key.name, key.status);
  }

  console.log('\n✓ All API keys added successfully!');
  console.log('\nIMPORTANT: Save these API keys securely. They will not be displayed again.');
  console.log('\nTo use an API key, include it in the x-api-key header:');
  console.log('  curl -H "x-api-key: <api-key>" -H "Authorization: Bearer <token>" <api-url>');
}

main().catch(console.error);
