#!/usr/bin/env ts-node

/**
 * Manage client preferences in DynamoDB
 * 
 * Usage:
 *   # Set preferences
 *   ts-node scripts/manage-client-preferences.ts set CLI001 --blocked PROV-APCO
 *   ts-node scripts/manage-client-preferences.ts set CLI001 --allowed PROV-CLIENT,PROV-ROUTE66
 *   ts-node scripts/manage-client-preferences.ts set CLI001 --preferred PROV-CLIENT --max 2
 * 
 *   # Get preferences
 *   ts-node scripts/manage-client-preferences.ts get CLI001
 * 
 *   # Delete preferences
 *   ts-node scripts/manage-client-preferences.ts delete CLI001
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({ region: 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.TABLE_NAME || 'iqq-config-dev';

interface ClientPreferences {
  PK: string;
  SK: string;
  GSI1PK: string;
  GSI1SK: string;
  clientId: string;
  allowedProviders?: string[];
  blockedProviders?: string[];
  preferredProviders?: string[];
  maxProviders?: number;
  updatedAt: string;
  createdAt?: string;
}

async function getPreferences(clientId: string): Promise<void> {
  console.log(`\n📖 Getting preferences for client: ${clientId}`);
  
  try {
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `CLIENT#${clientId}`,
        SK: 'PREFERENCES'
      }
    });

    const response = await docClient.send(command);
    
    if (!response.Item) {
      console.log(`❌ No preferences found for client ${clientId}`);
      return;
    }

    console.log('\n✅ Current preferences:');
    console.log(JSON.stringify(response.Item, null, 2));
  } catch (error) {
    console.error('❌ Error getting preferences:', error);
    throw error;
  }
}

async function setPreferences(
  clientId: string,
  options: {
    allowed?: string[];
    blocked?: string[];
    preferred?: string[];
    max?: number;
  }
): Promise<void> {
  console.log(`\n📝 Setting preferences for client: ${clientId}`);
  console.log('Options:', options);
  
  try {
    // Get existing preferences
    const getCommand = new GetCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `CLIENT#${clientId}`,
        SK: 'PREFERENCES'
      }
    });

    const existing = await docClient.send(getCommand);
    const existingPrefs = existing.Item as ClientPreferences | undefined;

    // Build preferences object
    const preferences: ClientPreferences = {
      PK: `CLIENT#${clientId}`,
      SK: 'PREFERENCES',
      GSI1PK: 'PREFERENCES',
      GSI1SK: `CLIENT#${clientId}`,
      clientId,
      updatedAt: new Date().toISOString(),
      createdAt: existingPrefs?.createdAt || new Date().toISOString()
    };

    // Apply updates
    if (options.allowed) {
      preferences.allowedProviders = options.allowed;
    } else if (existingPrefs?.allowedProviders) {
      preferences.allowedProviders = existingPrefs.allowedProviders;
    }

    if (options.blocked) {
      preferences.blockedProviders = options.blocked;
    } else if (existingPrefs?.blockedProviders) {
      preferences.blockedProviders = existingPrefs.blockedProviders;
    }

    if (options.preferred) {
      preferences.preferredProviders = options.preferred;
    } else if (existingPrefs?.preferredProviders) {
      preferences.preferredProviders = existingPrefs.preferredProviders;
    }

    if (options.max !== undefined) {
      preferences.maxProviders = options.max;
    } else if (existingPrefs?.maxProviders) {
      preferences.maxProviders = existingPrefs.maxProviders;
    }

    const putCommand = new PutCommand({
      TableName: TABLE_NAME,
      Item: preferences
    });

    await docClient.send(putCommand);
    
    console.log('\n✅ Preferences saved successfully:');
    console.log(JSON.stringify(preferences, null, 2));
  } catch (error) {
    console.error('❌ Error setting preferences:', error);
    throw error;
  }
}

async function deletePreferences(clientId: string): Promise<void> {
  console.log(`\n🗑️  Deleting preferences for client: ${clientId}`);
  
  try {
    const command = new DeleteCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `CLIENT#${clientId}`,
        SK: 'PREFERENCES'
      }
    });

    await docClient.send(command);
    console.log('✅ Preferences deleted successfully');
  } catch (error) {
    console.error('❌ Error deleting preferences:', error);
    throw error;
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const command = args[0];
const clientId = args[1];

if (!command || !clientId) {
  console.error(`
Usage:
  Set preferences:
    ts-node scripts/manage-client-preferences.ts set <clientId> [options]
    
    Options:
      --allowed <provider1,provider2>    Whitelist of allowed providers
      --blocked <provider1,provider2>    Blacklist of blocked providers
      --preferred <provider1,provider2>  Preferred provider order
      --max <number>                     Maximum number of providers
    
  Get preferences:
    ts-node scripts/manage-client-preferences.ts get <clientId>
    
  Delete preferences:
    ts-node scripts/manage-client-preferences.ts delete <clientId>

Examples:
  # Block APCO provider for CLI001
  ts-node scripts/manage-client-preferences.ts set CLI001 --blocked PROV-APCO
  
  # Only allow Client and Route66 for CLI002
  ts-node scripts/manage-client-preferences.ts set CLI002 --allowed PROV-CLIENT,PROV-ROUTE66
  
  # Prefer Client provider and limit to 2 providers
  ts-node scripts/manage-client-preferences.ts set CLI001 --preferred PROV-CLIENT --max 2
  
  # Get current preferences
  ts-node scripts/manage-client-preferences.ts get CLI001
  `);
  process.exit(1);
}

async function main() {
  try {
    if (command === 'get') {
      await getPreferences(clientId);
    } else if (command === 'delete') {
      await deletePreferences(clientId);
    } else if (command === 'set') {
      const options: any = {};
      
      for (let i = 2; i < args.length; i++) {
        if (args[i] === '--allowed' && args[i + 1]) {
          options.allowed = args[i + 1].split(',');
          i++;
        } else if (args[i] === '--blocked' && args[i + 1]) {
          options.blocked = args[i + 1].split(',');
          i++;
        } else if (args[i] === '--preferred' && args[i + 1]) {
          options.preferred = args[i + 1].split(',');
          i++;
        } else if (args[i] === '--max' && args[i + 1]) {
          options.max = parseInt(args[i + 1]);
          i++;
        }
      }
      
      await setPreferences(clientId, options);
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
    
    console.log('\n✨ Done!');
    process.exit(0);
  } catch (error) {
    console.error('\n💥 Failed:', error);
    process.exit(1);
  }
}

main();
