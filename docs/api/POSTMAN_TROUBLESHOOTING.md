# Postman Troubleshooting Guide

## Issue: HTML Error Page When Getting OAuth Token

If you see an HTML error page like this when calling the OAuth token endpoint:
```html
<!DOCTYPE html><html lang="en">...An error was encountered with the requested page...</html>
```

This means Postman is not sending the request correctly. Here are the solutions:

## Solution 1: Use the Alternative Token Request (Recommended)

The updated Postman collection includes an "Get OAuth Token (Alternative)" request that automatically encodes credentials.

### Steps:
1. Open Postman
2. Select "Get OAuth Token (Alternative)" request
3. Make sure your environment has `clientId` and `clientSecret` set
4. Click "Send"
5. The pre-request script will automatically encode credentials

## Solution 2: Manually Set Base64 Credentials

### Step 1: Encode Your Credentials

You need to Base64 encode your `clientId:clientSecret`.

#### Option A: Using Command Line
```bash
# Replace with your actual credentials
CLIENT_ID="25oa5u3vup2jmhl270e7shudkl"
CLIENT_SECRET="your-secret-here"

# Mac/Linux
echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64

# Windows PowerShell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${CLIENT_ID}:${CLIENT_SECRET}"))
```

#### Option B: Using Online Tool
1. Go to https://www.base64encode.org/
2. Enter: `clientId:clientSecret` (replace with actual values)
3. Click "Encode"
4. Copy the result

#### Option C: Using Postman Console
1. Open Postman Console (View → Show Postman Console)
2. Go to any request
3. In Pre-request Script tab, paste:
```javascript
const clientId = "25oa5u3vup2jmhl270e7shudkl";
const clientSecret = "your-secret-here";
const credentials = clientId + ':' + clientSecret;
const base64Credentials = btoa(credentials);
console.log('Base64 Credentials:', base64Credentials);
```
4. Click "Send" and check console for output

### Step 2: Add to Environment

1. Go to your environment (iQQ Dev Environment)
2. Add new variable:
   - Variable: `base64ClientCredentials`
   - Initial Value: (paste the base64 string)
   - Current Value: (paste the base64 string)
3. Save

### Step 3: Test the Request

1. Select "Get OAuth Token" request
2. Verify the Authorization header shows: `Basic {{base64ClientCredentials}}`
3. Click "Send"
4. You should get a JSON response with `access_token`

## Solution 3: Use cURL Instead

If Postman continues to have issues, use cURL:

```bash
CLIENT_ID="25oa5u3vup2jmhl270e7shudkl"
CLIENT_SECRET="your-secret-here"
COGNITO_DOMAIN="iqq-dev-ib9i1hvt"

curl -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read"
```

Then copy the `access_token` from the response and manually set it in Postman environment.

## Common Issues and Fixes

### Issue: "Invalid client" Error

**Cause**: Client ID or Client Secret is incorrect

**Fix**:
1. Verify your credentials in AWS Console
2. Go to Cognito → User Pools → us-east-1_Wau5rEb2N → App clients
3. Check Client ID matches: `25oa5u3vup2jmhl270e7shudkl`
4. Regenerate Client Secret if needed

### Issue: "Invalid scope" Error

**Cause**: The scope `iqq-api/read` is not configured for the app client

**Fix**:
1. Go to AWS Console → Cognito → User Pools
2. Select your user pool
3. Go to App clients → Your app client → Edit
4. Under "OAuth 2.0 grant types", ensure "Client credentials" is checked
5. Under "Custom scopes", ensure `iqq-api/read` is added

### Issue: "Unauthorized" Error

**Cause**: OAuth flows not enabled for the app client

**Fix**:
Run this AWS CLI command to enable OAuth flows:

```bash
aws cognito-idp update-user-pool-client \
  --user-pool-id us-east-1_Wau5rEb2N \
  --client-id 25oa5u3vup2jmhl270e7shudkl \
  --allowed-o-auth-flows client_credentials \
  --allowed-o-auth-scopes iqq-api/read \
  --allowed-o-auth-flows-user-pool-client \
  --region us-east-1
```

### Issue: Postman Shows HTML Instead of JSON

**Cause**: Postman is treating the request as a browser request

**Fix**:
1. Make sure you're using POST method (not GET)
2. Verify Content-Type header is `application/x-www-form-urlencoded`
3. Use the "Alternative" request which has proper headers
4. Disable "Automatically follow redirects" in Postman settings

## Verification Steps

### 1. Check Request Format

Your request should look like this:

```
POST https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token
Content-Type: application/x-www-form-urlencoded
Authorization: Basic <base64-encoded-credentials>

grant_type=client_credentials&scope=iqq-api/read
```

### 2. Check Response

Success response (200 OK):
```json
{
  "access_token": "eyJraWQiOiJxSW5UR2EyYnJBZXNLbTBpTFJUUW1wMDA3VStmejdQNVBqYXBGdGJCVGNNPSIsImFsZyI6IlJTMjU2In0...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

Error response (400/401):
```json
{
  "error": "invalid_client",
  "error_description": "Client authentication failed"
}
```

### 3. Test with Script

Use the test script to verify everything works:

```bash
export IQQ_CLIENT_SECRET="your-secret-here"
./scripts/test-api-complete.sh
```

If the script works but Postman doesn't, the issue is with Postman configuration.

## Quick Fix: Use Pre-Request Script

Add this to the "Get OAuth Token" request's Pre-request Script:

```javascript
// Encode credentials
const clientId = pm.environment.get('clientId');
const clientSecret = pm.environment.get('clientSecret');

if (!clientId || !clientSecret) {
    console.error('clientId or clientSecret not set in environment');
    throw new Error('Missing credentials');
}

const credentials = clientId + ':' + clientSecret;
const base64Credentials = btoa(credentials);

// Set as environment variable
pm.environment.set('base64ClientCredentials', base64Credentials);

console.log('Credentials encoded successfully');
console.log('Client ID:', clientId);
console.log('Base64:', base64Credentials.substring(0, 20) + '...');
```

Then in the request, use:
- Header: `Authorization: Basic {{base64ClientCredentials}}`

## Alternative: Use Postman's Built-in OAuth 2.0

Instead of manually calling the token endpoint, you can use Postman's OAuth 2.0 feature:

1. Go to Authorization tab
2. Type: OAuth 2.0
3. Configure:
   - Grant Type: Client Credentials
   - Access Token URL: `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token`
   - Client ID: `25oa5u3vup2jmhl270e7shudkl`
   - Client Secret: `your-secret`
   - Scope: `iqq-api/read`
   - Client Authentication: Send as Basic Auth header
4. Click "Get New Access Token"
5. Click "Use Token"

## Still Having Issues?

1. **Check Postman Console**: View → Show Postman Console to see detailed request/response
2. **Disable SSL Verification**: Settings → General → SSL certificate verification (OFF)
3. **Clear Cookies**: Settings → Cookies → Remove All
4. **Try Different Request**: Use the "Alternative" version in the collection
5. **Use cURL**: Verify the endpoint works outside Postman
6. **Check AWS Console**: Verify Cognito app client configuration

## Contact Support

If none of these solutions work:
1. Export the request from Postman (right-click → Export)
2. Check the raw HTTP request
3. Compare with working cURL command
4. Contact: api-support@iqq.com with:
   - Postman version
   - Request export
   - Error message
   - Console logs
