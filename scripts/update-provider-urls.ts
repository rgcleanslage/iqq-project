#!/usr/bin/env ts-node

/**
 * Update provider URLs in DynamoDB after Lambda deployment
 * 
 * This script extracts Lambda Function URLs from CloudFormation outputs
 * and updates the provider records in DynamoDB.
 * 
 * Usage:
 *   ts-node scripts/update-provider-urls.ts
 * 
 * Or with environment:
 *   TABLE_NAME=iqq-config-dev STACK_NAME=iqq-providers-dev ts-node scripts/update-provider-urls.ts
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { CloudFormationClient, DescribeStacksCommand } from '@aws-sdk/client-cloudformation';

const region = process.env.AWS_REGION || 'us-east-1';
const dynamoClient = new DynamoDBClient({ region });
const docClient = DynamoDBDocumentClient.from(dynamoClient);
const cfnClient = new CloudFormationClient({ region });

const TABLE_NAME = process.env.TABLE_NAME || 'iqq-config-dev';
const STACK_NAME = process.env.STACK_NAME || 'iqq-providers-dev';

interface ProviderMapping {
  providerId: string;
  outputKey: string;
}

const providerMappings: ProviderMapping[] = [
  { providerId: 'PROV-CLIENT', outputKey: 'ClientProviderUrl' },
  { providerId: 'PROV-ROUTE66', outputKey: 'Route66ProviderUrl' },
  { providerId: 'PROV-APCO', outputKey: 'APCOProviderUrl' }
];

async function getStackOutputs(): Promise<Record<string, string>> {
  console.log(`📋 Fetching CloudFormation stack outputs: ${STACK_NAME}`);
  
  const command = new DescribeStacksCommand({
    StackName: STACK_NAME
  });
  
  const response = await cfnClient.send(command);
  const stack = response.Stacks?.[0];
  
  if (!stack) {
    throw new Error(`Stack ${STACK_NAME} not found`);
  }
  
  const outputs: Record<string, string> = {};
  
  for (const output of stack.Outputs || []) {
    if (output.OutputKey && output.OutputValue) {
      outputs[output.OutputKey] = output.OutputValue;
    }
  }
  
  return outputs;
}

async function updateProviderUrl(providerId: string, providerUrl: string): Promise<void> {
  console.log(`🔄 Updating ${providerId} with URL: ${providerUrl}`);
  
  const command = new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: `PROVIDER#${providerId}`,
      SK: 'METADATA'
    },
    UpdateExpression: 'SET providerUrl = :url, updatedAt = :timestamp',
    ExpressionAttributeValues: {
      ':url': providerUrl,
      ':timestamp': new Date().toISOString()
    }
  });
  
  await docClient.send(command);
  console.log(`✅ Updated ${providerId}`);
}

async function main() {
  console.log('🚀 Starting provider URL update process\n');
  
  try {
    // Get CloudFormation outputs
    const outputs = await getStackOutputs();
    
    console.log('\n📦 Found outputs:');
    Object.entries(outputs).forEach(([key, value]) => {
      if (key.includes('ProviderUrl')) {
        console.log(`  - ${key}: ${value}`);
      }
    });
    
    console.log('\n🔄 Updating DynamoDB records...\n');
    
    // Update each provider
    for (const mapping of providerMappings) {
      const url = outputs[mapping.outputKey];
      
      if (!url) {
        console.warn(`⚠️  Warning: ${mapping.outputKey} not found in stack outputs`);
        continue;
      }
      
      await updateProviderUrl(mapping.providerId, url);
    }
    
    console.log('\n✨ All provider URLs updated successfully!');
    
  } catch (error) {
    console.error('\n💥 Error updating provider URLs:', error);
    throw error;
  }
}

// Run the update
main()
  .then(() => {
    console.log('\n🎉 Update complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Update failed:', error);
    process.exit(1);
  });
