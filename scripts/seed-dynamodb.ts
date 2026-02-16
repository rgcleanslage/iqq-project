#!/usr/bin/env ts-node

/**
 * Seed DynamoDB with initial configuration data
 * 
 * Usage:
 *   npm install -g ts-node
 *   ts-node scripts/seed-dynamodb.ts
 * 
 * Or with environment:
 *   TABLE_NAME=iqq-config-dev ts-node scripts/seed-dynamodb.ts
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, BatchWriteCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({ region: 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.TABLE_NAME || 'iqq-config-dev';

// Sample clients
const clients = [
  {
    PK: 'CLIENT#CLI001',
    SK: 'METADATA',
    GSI1PK: 'CLIENT',
    GSI1SK: 'CLI001',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'CLIENT#CLI001',
    clientId: 'CLI001',
    clientName: 'Premium Auto Dealership',
    status: 'ACTIVE',
    contactInfo: {
      email: 'quotes@premiumauto.com',
      phone: '1-800-555-0100'
    },
    createdAt: new Date().toISOString()
  },
  {
    PK: 'CLIENT#CLI002',
    SK: 'METADATA',
    GSI1PK: 'CLIENT',
    GSI1SK: 'CLI002',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'CLIENT#CLI002',
    clientId: 'CLI002',
    clientName: 'Elite Motors Group',
    status: 'ACTIVE',
    contactInfo: {
      email: 'insurance@elitemotors.com',
      phone: '1-800-555-0200'
    },
    createdAt: new Date().toISOString()
  }
];

// Sample products
const products = [
  {
    PK: 'PRODUCT#PROD-MBP-001',
    SK: 'METADATA',
    GSI1PK: 'PRODUCTTYPE#MBP',
    GSI1SK: 'PROD-MBP-001',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'PRODUCT#PROD-MBP-001',
    productId: 'PROD-MBP-001',
    productName: 'Mechanical Breakdown Protection',
    productType: 'MBP',
    description: 'Comprehensive coverage for mechanical and electrical failures',
    basePremium: 1199.99,
    status: 'ACTIVE',
    createdAt: new Date().toISOString()
  },
  {
    PK: 'PRODUCT#PROD-GAP-001',
    SK: 'METADATA',
    GSI1PK: 'PRODUCTTYPE#GAP',
    GSI1SK: 'PROD-GAP-001',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'PRODUCT#PROD-GAP-001',
    productId: 'PROD-GAP-001',
    productName: 'Guaranteed Asset Protection',
    productType: 'GAP',
    description: 'Covers loan balance if vehicle is totaled',
    basePremium: 599.99,
    status: 'ACTIVE',
    createdAt: new Date().toISOString()
  },
  {
    PK: 'PRODUCT#PROD-VDP-001',
    SK: 'METADATA',
    GSI1PK: 'PRODUCTTYPE#VDP',
    GSI1SK: 'PROD-VDP-001',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'PRODUCT#PROD-VDP-001',
    productId: 'PROD-VDP-001',
    productName: 'Vehicle Depreciation Protection',
    productType: 'VDP',
    description: 'Protects against vehicle value depreciation',
    basePremium: 399.99,
    status: 'ACTIVE',
    createdAt: new Date().toISOString()
  }
];

// Sample providers
// NOTE: Update these URLs after deploying the Lambda functions
const providers = [
  {
    PK: 'PROVIDER#PROV-CLIENT',
    SK: 'METADATA',
    GSI1PK: 'PROVIDER',
    GSI1SK: 'PROV-CLIENT',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'PROVIDER#PROV-CLIENT',
    providerId: 'PROV-CLIENT',
    providerName: 'Client Insurance',
    providerUrl: 'https://your-function-url.lambda-url.us-east-1.on.aws/',
    lambdaArn: 'arn:aws:lambda:us-east-1:785826687678:function:iqq-provider-client-dev', // Kept for backward compatibility
    responseFormat: 'CSV',
    adapterArn: 'arn:aws:lambda:us-east-1:785826687678:function:iqq-adapter-csv-dev',
    rating: 'A+',
    status: 'ACTIVE',
    timeout: 30000,
    createdAt: new Date().toISOString()
  },
  {
    PK: 'PROVIDER#PROV-ROUTE66',
    SK: 'METADATA',
    GSI1PK: 'PROVIDER',
    GSI1SK: 'PROV-ROUTE66',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'PROVIDER#PROV-ROUTE66',
    providerId: 'PROV-ROUTE66',
    providerName: 'Route 66 Insurance',
    providerUrl: 'https://your-function-url.lambda-url.us-east-1.on.aws/',
    lambdaArn: 'arn:aws:lambda:us-east-1:785826687678:function:iqq-provider-route66-dev', // Kept for backward compatibility
    responseFormat: 'JSON',
    adapterArn: null,
    rating: 'A',
    status: 'ACTIVE',
    timeout: 30000,
    createdAt: new Date().toISOString()
  },
  {
    PK: 'PROVIDER#PROV-APCO',
    SK: 'METADATA',
    GSI1PK: 'PROVIDER',
    GSI1SK: 'PROV-APCO',
    GSI2PK: 'STATUS#ACTIVE',
    GSI2SK: 'PROVIDER#PROV-APCO',
    providerId: 'PROV-APCO',
    providerName: 'APCO Insurance',
    providerUrl: 'https://your-function-url.lambda-url.us-east-1.on.aws/',
    lambdaArn: 'arn:aws:lambda:us-east-1:785826687678:function:iqq-provider-apco-dev', // Kept for backward compatibility
    responseFormat: 'XML',
    adapterArn: 'arn:aws:lambda:us-east-1:785826687678:function:iqq-adapter-xml-dev',
    rating: 'A-',
    status: 'ACTIVE',
    timeout: 30000,
    createdAt: new Date().toISOString()
  }
];

// Sample provider mappings
const mappings = [
  {
    PK: 'MAPPING#PROD-MBP-001#PROV-CLIENT',
    SK: 'VERSION#1',
    GSI1PK: 'PRODUCT#PROD-MBP-001',
    GSI1SK: 'MAPPING#PROV-CLIENT',
    productId: 'PROD-MBP-001',
    providerId: 'PROV-CLIENT',
    version: 1,
    active: true,
    mappingConfig: {
      request: {
        product_code: 'MBP',
        coverage_type: 'COMPREHENSIVE'
      },
      response: {
        quoteId: 'quote_id',
        premium: 'premium',
        coverageAmount: 'coverage_amt',
        term: 'term_months'
      },
      transformations: {
        premium: 'parseFloat',
        term: 'parseInt'
      }
    },
    createdAt: new Date().toISOString()
  },
  {
    PK: 'MAPPING#PROD-MBP-001#PROV-ROUTE66',
    SK: 'VERSION#1',
    GSI1PK: 'PRODUCT#PROD-MBP-001',
    GSI1SK: 'MAPPING#PROV-ROUTE66',
    productId: 'PROD-MBP-001',
    providerId: 'PROV-ROUTE66',
    version: 1,
    active: true,
    mappingConfig: {
      request: {
        product: 'MBP',
        coverageLevel: 'premium'
      },
      response: {
        quoteId: 'quoteId',
        premium: 'pricing.premium',
        coverageAmount: 'pricing.coverage',
        term: 'terms.months'
      },
      transformations: {
        premium: 'parseFloat',
        term: 'parseInt'
      }
    },
    createdAt: new Date().toISOString()
  },
  {
    PK: 'MAPPING#PROD-MBP-001#PROV-APCO',
    SK: 'VERSION#1',
    GSI1PK: 'PRODUCT#PROD-MBP-001',
    GSI1SK: 'MAPPING#PROV-APCO',
    productId: 'PROD-MBP-001',
    providerId: 'PROV-APCO',
    version: 1,
    active: true,
    mappingConfig: {
      request: {
        ProductCode: 'MBP',
        CoverageType: 'Full'
      },
      response: {
        quoteId: 'Quote.ID',
        premium: 'Quote.Premium',
        coverageAmount: 'Quote.Coverage.Amount',
        term: 'Quote.Term.Months'
      },
      transformations: {
        premium: 'parseFloat',
        term: 'parseInt'
      }
    },
    createdAt: new Date().toISOString()
  }
];

async function seedData() {
  console.log(`🌱 Seeding DynamoDB table: ${TABLE_NAME}`);
  
  const allItems = [...clients, ...products, ...providers, ...mappings];
  
  // DynamoDB BatchWrite can handle max 25 items at a time
  const batchSize = 25;
  
  for (let i = 0; i < allItems.length; i += batchSize) {
    const batch = allItems.slice(i, i + batchSize);
    
    const command = new BatchWriteCommand({
      RequestItems: {
        [TABLE_NAME]: batch.map(item => ({
          PutRequest: {
            Item: item
          }
        }))
      }
    });
    
    try {
      await docClient.send(command);
      console.log(`✅ Inserted batch ${Math.floor(i / batchSize) + 1} (${batch.length} items)`);
    } catch (error) {
      console.error(`❌ Error inserting batch:`, error);
      throw error;
    }
  }
  
  console.log(`\n✨ Successfully seeded ${allItems.length} items!`);
  console.log(`\nSummary:`);
  console.log(`  - Clients: ${clients.length}`);
  console.log(`  - Products: ${products.length}`);
  console.log(`  - Providers: ${providers.length}`);
  console.log(`  - Mappings: ${mappings.length}`);
}

// Run the seed function
seedData()
  .then(() => {
    console.log('\n🎉 Seeding complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Seeding failed:', error);
    process.exit(1);
  });
