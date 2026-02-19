# SoapUI Testing Guide for iQQ API

## Overview

This guide shows you how to test the iQQ Insurance Quoting Platform API using SoapUI with OAuth 2.0 client credentials authentication.

## Prerequisites

1. **Install SoapUI**
   - Download from: https://www.soapui.org/downloads/soapui/
   - Use either SoapUI Open Source or SoapUI Pro
   - Minimum version: 5.7.0 (for OAuth 2.0 support)

2. **API Configuration**
   - API Gateway URL: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev`
   - Cognito Token URL: `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token`
   - Client ID: `YOUR_CLIENT_ID`
   - Client Secret: `YOUR_CLIENT_SECRET`
   - Scopes: `iqq-api/read iqq-api/write`

---

## Step 1: Create New REST Project

1. Open SoapUI
2. Click **File → New REST Project**
3. Enter project details:
   - **Project Name**: `iQQ Insurance API`
   - **URI**: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev`
4. Click **OK**

---

## Step 2: Configure OAuth 2.0 Authentication

### Option A: Using SoapUI Pro (Recommended)

1. Right-click on the project → **Show Project View**
2. Click on **Auth** tab at the bottom
3. Select **OAuth 2.0** from the dropdown
4. Configure OAuth 2.0 settings:
   - **Grant Type**: `Client Credentials`
   - **Access Token URI**: `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token`
   - **Client ID**: `YOUR_CLIENT_ID`
   - **Client Secret**: `YOUR_CLIENT_SECRET`
   - **Scope**: `iqq-api/read iqq-api/write`
   - **Client Authentication**: `Send as Basic Auth Header`
5. Click **Get Access Token**
6. Verify token is retrieved successfully

### Option B: Using SoapUI Open Source (Manual Token)

Since SoapUI Open Source has limited OAuth 2.0 support, you'll need to get the token manually:

1. **Get Token via cURL** (in terminal):
```bash
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "YOUR_CLIENT_ID:YOUR_CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=iqq-api/read iqq-api/write"
```

2. **Copy the access_token** from the response
3. In SoapUI, for each request:
   - Click on **Headers** tab
   - Add header: `Authorization` = `Bearer <your_access_token>`

**Note**: Tokens expire after 1 hour. You'll need to refresh manually.

---

## Step 3: Create Test Requests

### 3.1 Lender Service Test

1. Right-click on the project → **New Resource**
2. Configure:
   - **Resource Name**: `Lender`
   - **Resource Path**: `/lender`
3. Right-click on the resource → **New Method**
4. Configure:
   - **Method**: `GET`
5. Click on the request
6. Add query parameter:
   - **Name**: `lenderId`
   - **Value**: `LENDER-123`
7. Click **Send** (green play button)

**Expected Response** (200 OK):
```json
{
  "lenderId": "LENDER-123",
  "lenderName": "Premium Auto Finance",
  "lenderType": "Captive",
  "contactInfo": {
    "phone": "1-800-555-0100",
    "email": "quotes@premiumautofinance.com",
    "website": "https://www.premiumautofinance.com"
  },
  "productsOffered": [
    "MBP",
    "GAP",
    "Vehicle Depreciation Protection"
  ],
  "ratingInfo": {
    "creditRating": "A+",
    "yearsInBusiness": 25,
    "customerSatisfactionScore": 4.7
  }
}
```

### 3.2 Package Service Test

1. Create new resource:
   - **Resource Name**: `Package`
   - **Resource Path**: `/package`
2. Create GET method
3. Add query parameter:
   - **Name**: `packageId`
   - **Value**: `PKG-456`
4. Click **Send**

**Expected Response** (200 OK):
```json
{
  "packageId": "PKG-456",
  "packageName": "Premium Protection Bundle",
  "packageType": "Premium",
  "products": [
    {
      "productId": "PROD-MBP-001",
      "productName": "Mechanical Breakdown Protection",
      "productType": "MBP",
      "coverage": "Comprehensive powertrain and component coverage",
      "premium": 1299.99
    }
  ],
  "pricing": {
    "basePrice": 2299.97,
    "discountPercentage": 10,
    "totalPrice": 2069.97,
    "currency": "USD"
  }
}
```

### 3.3 Product Service Test

1. Create new resource:
   - **Resource Name**: `Product`
   - **Resource Path**: `/product`
2. Create GET method
3. Add query parameter:
   - **Name**: `productId`
   - **Value**: `PROD-789`
4. Click **Send**

**Expected Response** (200 OK):
```json
{
  "productId": "PROD-789",
  "productName": "Mechanical Breakdown Protection",
  "productType": "MBP",
  "description": "Comprehensive coverage for mechanical and electrical failures",
  "coverage": {
    "coverageType": "Comprehensive",
    "coverageLimit": 100000,
    "deductible": 100,
    "term": "60 months / 60,000 miles"
  },
  "pricing": {
    "basePremium": 1199.99,
    "adminFee": 50,
    "taxRate": 0.06,
    "totalPremium": 1324.99,
    "currency": "USD"
  }
}
```

### 3.4 Document Service Test

1. Create new resource:
   - **Resource Name**: `Document`
   - **Resource Path**: `/document`
2. Create GET method
3. Add query parameter:
   - **Name**: `documentId`
   - **Value**: `DOC-101`
4. Click **Send**

**Expected Response** (200 OK):
```json
{
  "documentId": "DOC-101",
  "documentName": "Insurance Policy Document",
  "documentType": "Policy",
  "status": "Issued",
  "content": {
    "format": "PDF",
    "size": 245678,
    "url": "https://s3.amazonaws.com/iqq-documents/policy-doc-001.pdf"
  }
}
```

---

## Step 4: Create Test Suite with Assertions

### 4.1 Create Test Suite

1. Right-click on project → **Generate TestSuite**
2. Name it: `iQQ API Test Suite`
3. Select all 4 resources (Lender, Package, Product, Document)
4. Click **OK**

### 4.2 Add Assertions to Lender Test

1. Open the Lender test case
2. Double-click on the test step
3. Click **Assertions** tab (bottom left)
4. Add assertions:

**Valid HTTP Status Code**:
- Click **+** → **Compliance, Status, Standards** → **Valid HTTP Status Codes**
- Enter: `200`

**JsonPath Match**:
- Click **+** → **Property Content** → **JsonPath Match**
- JsonPath: `$.lenderId`
- Expected Value: `LENDER-123`

**JsonPath Exists**:
- Click **+** → **Property Content** → **JsonPath Count**
- JsonPath: `$.productsOffered`
- Expected Count: `3`

**Response Time**:
- Click **+** → **SLA** → **Response SLA**
- Max Time: `2000` (milliseconds)

### 4.3 Add Assertions to Other Services

Repeat similar assertions for Package, Product, and Document services:

**Package Service Assertions**:
- Status Code: `200`
- JsonPath: `$.packageId` = `PKG-456`
- JsonPath: `$.pricing.totalPrice` exists
- Response Time: < 2000ms

**Product Service Assertions**:
- Status Code: `200`
- JsonPath: `$.productId` = `PROD-789`
- JsonPath: `$.coverage.coverageLimit` = `100000`
- Response Time: < 2000ms

**Document Service Assertions**:
- Status Code: `200`
- JsonPath: `$.documentId` = `DOC-101`
- JsonPath: `$.status` = `Issued`
- Response Time: < 2000ms

---

## Step 5: Run Test Suite

1. Right-click on the test suite → **Run**
2. Review results in the **TestSuite Log**
3. Check for:
   - ✅ All tests passed
   - ✅ All assertions passed
   - ✅ Response times within limits

---

## Step 6: Create Data-Driven Tests (Optional)

### 6.1 Create Test Data File

Create a CSV file `test-data.csv`:

```csv
lenderId,packageId,productId,documentId
LENDER-123,PKG-456,PROD-789,DOC-101
LENDER-456,PKG-789,PROD-123,DOC-202
LENDER-789,PKG-123,PROD-456,DOC-303
```

### 6.2 Configure Data Source

1. Right-click on test suite → **Add Step** → **DataSource**
2. Configure:
   - **Name**: `TestData`
   - **Type**: `File`
   - **File**: Browse to `test-data.csv`
3. Click **OK**

### 6.3 Use Data in Test Steps

1. Edit each test step
2. Replace hardcoded values with properties:
   - Lender: `${TestData#lenderId}`
   - Package: `${TestData#packageId}`
   - Product: `${TestData#productId}`
   - Document: `${TestData#documentId}`

### 6.4 Add DataSource Loop

1. Right-click on test suite → **Add Step** → **DataSource Loop**
2. Configure to loop through all rows in TestData

---

## Step 7: Negative Testing

### 7.1 Test Missing Authorization

1. Create new test case: `Unauthorized Access Test`
2. Create request without Authorization header
3. Add assertion:
   - Status Code: `401`
   - Response contains: `Unauthorized`

### 7.2 Test Invalid Token

1. Create new test case: `Invalid Token Test`
2. Add Authorization header with invalid token: `Bearer invalid_token_here`
3. Add assertion:
   - Status Code: `401` or `403`

### 7.3 Test Missing Parameters

1. Create new test case: `Missing Parameters Test`
2. Create requests without query parameters
3. Add assertions based on expected behavior

### 7.4 Test Invalid IDs

1. Create new test case: `Invalid ID Test`
2. Use non-existent IDs:
   - `lenderId=INVALID-999`
   - `packageId=INVALID-999`
3. Verify appropriate error responses

---

## Step 8: Performance Testing (SoapUI Pro)

### 8.1 Create Load Test

1. Right-click on test case → **New LoadTest**
2. Configure:
   - **Name**: `API Load Test`
   - **Limit**: `60` seconds
   - **Threads**: `10` (concurrent users)
   - **Strategy**: `Simple`
3. Click **Run**

### 8.2 Monitor Metrics

Watch for:
- **TPS** (Transactions Per Second)
- **Average Response Time**
- **Min/Max Response Times**
- **Error Rate**

### 8.3 Set Performance Assertions

1. Click **LoadTest Assertions**
2. Add:
   - **Max Errors**: `0`
   - **Average TPS**: `> 5`
   - **Max Response Time**: `< 3000ms`

---

## Step 9: Export and Share

### 9.1 Export Project

1. Right-click on project → **Export Project**
2. Save as: `iQQ-API-SoapUI-Project.xml`
3. Share with team members

### 9.2 Generate Reports (SoapUI Pro)

1. Right-click on test suite → **Generate Report**
2. Select format: `PDF`, `HTML`, or `XLS`
3. Save report

---

## Troubleshooting

### Issue: 401 Unauthorized

**Cause**: Token expired or invalid

**Solution**:
1. Get a fresh token using cURL command
2. Update Authorization header
3. Tokens expire after 1 hour

### Issue: Connection Timeout

**Cause**: Network issues or Lambda cold start

**Solution**:
1. Increase timeout in SoapUI preferences
2. Retry the request (Lambda will be warm)

### Issue: SSL Certificate Error

**Cause**: SSL verification issues

**Solution**:
1. Go to **File → Preferences → SSL Settings**
2. Disable SSL certificate validation (for testing only)

### Issue: OAuth 2.0 Not Working in Open Source

**Cause**: Limited OAuth support in free version

**Solution**:
1. Use manual token approach (Option B above)
2. Or upgrade to SoapUI Pro for full OAuth 2.0 support

---

## Best Practices

1. **Token Management**
   - Store tokens securely
   - Refresh tokens before they expire
   - Use project-level properties for tokens

2. **Test Organization**
   - Group related tests in test suites
   - Use descriptive names for tests
   - Add comments to complex assertions

3. **Assertions**
   - Always verify status codes
   - Check critical response fields
   - Add response time assertions

4. **Data-Driven Testing**
   - Use external data sources for scalability
   - Test with realistic data
   - Include edge cases

5. **Version Control**
   - Export project XML regularly
   - Store in version control (Git)
   - Document changes

---

## Quick Reference

### Get OAuth Token (cURL)
```bash
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "YOUR_CLIENT_ID:YOUR_CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=iqq-api/read iqq-api/write"
```

### API Endpoints
- **Lender**: `GET /dev/lender?lenderId=LENDER-123`
- **Package**: `GET /dev/package?packageId=PKG-456`
- **Product**: `GET /dev/product?productId=PROD-789`
- **Document**: `GET /dev/document?documentId=DOC-101`

### Common Headers
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

---

## Next Steps

1. ✅ Set up SoapUI project with OAuth 2.0
2. ✅ Create test requests for all 4 services
3. ✅ Add assertions to validate responses
4. ✅ Run test suite and verify all tests pass
5. ✅ Create data-driven tests with CSV
6. ✅ Add negative test cases
7. ✅ Run performance tests (if using Pro)
8. ✅ Export project and share with team

---

## Support

For issues or questions:
- Check CloudWatch logs for Lambda errors
- Review API Gateway logs
- Verify Cognito token is valid
- Check network connectivity

**Happy Testing!** 🎉
