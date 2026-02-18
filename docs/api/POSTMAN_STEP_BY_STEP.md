# Postman Step-by-Step Setup Guide

## The Error You're Seeing

```
"message": "Invalid key=value pair (missing equal-sign) in Authorization header..."
```

This error means Postman is sending the wrong type of Authorization header. Here's how to fix it.

## Solution: Use the Fixed Collection

### Step 1: Import the Fixed Collection

1. Open Postman
2. Click **Import** button (top left)
3. Select **`docs/api/postman-collection-fixed.json`**
4. Click **Import**

### Step 2: Import the Environment

1. Click **Import** again
2. Select **`docs/api/postman-environment.json`**
3. Click **Import**

### Step 3: Configure Environment

1. Click the environment dropdown (top right)
2. Select **"iQQ Dev Environment"**
3. Click the eye icon (👁️) next to the environment name
4. Click **Edit**
5. Update these values:
   - `clientId`: `25oa5u3vup2jmhl270e7shudkl` (should already be set)
   - `clientSecret`: **YOUR_ACTUAL_SECRET** (replace this!)
   - `apiKey`: `Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH` (should already be set)
6. Click **Save**

### Step 4: Get OAuth Token

1. In the collection, expand **"Authentication"** folder
2. Click **"Get OAuth Token (Working)"**
3. Click **Send**
4. You should see:
   ```json
   {
     "access_token": "eyJraWQiOiJxSW5UR2EyYnJBZXNLbTBpTFJUUW1wMDA3VStmejdQNVBqYXBGdGJCVGNNPSIsImFsZyI6IlJTMjU2In0...",
     "expires_in": 3600,
     "token_type": "Bearer"
   }
   ```
5. Check the **Console** (View → Show Postman Console) for success messages

### Step 5: Test API Endpoints

Now test any endpoint:

1. Click **"Package" → "Get Package"**
2. Click **Send**
3. You should get a 200 response with quote data

## What the Fixed Collection Does Differently

### The Problem
The original collection used Postman's built-in Basic Auth, which doesn't work correctly with Cognito's OAuth endpoint.

### The Solution
The fixed collection:
1. Uses **no auth** type for the OAuth request
2. Has a **pre-request script** that:
   - Reads `clientId` and `clientSecret` from environment
   - Encodes them as Base64
   - Sets the Authorization header directly
3. Uses the **full URL** (not a variable) to avoid any URL parsing issues

## Verify It's Working

### Check 1: Console Output
After sending the OAuth token request, check the Postman Console (View → Show Postman Console):

You should see:
```
✓ Credentials encoded
Client ID: 25oa5u3vup2jmhl270e7shudkl
Base64 (first 30 chars): MjVvYTV1M3Z1cDJqbWhsMjcwZTdzaH...
✓ Authorization header set
✓ SUCCESS: Token obtained and saved
Token expires in: 3600 seconds
```

### Check 2: Environment Variables
After getting the token, check your environment:
- `accessToken` should be set (long JWT string)
- `tokenExpiry` should be set (timestamp)

### Check 3: API Calls Work
Try the Package endpoint - it should return 200 with quote data.

## Still Getting Errors?

### Error: "clientId or clientSecret not set"
**Fix**: Make sure you selected the "iQQ Dev Environment" in the dropdown (top right)

### Error: "Invalid client"
**Fix**: Your `clientSecret` is wrong. Get the correct one:
```bash
aws cognito-idp describe-user-pool-client \
  --user-pool-id us-east-1_Wau5rEb2N \
  --client-id 25oa5u3vup2jmhl270e7shudkl \
  --region us-east-1 \
  --query 'UserPoolClient.ClientSecret' \
  --output text
```

### Error: Still getting HTML response
**Fix**: 
1. Make sure you're using **"Get OAuth Token (Working)"** from the fixed collection
2. Check that the URL is exactly: `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token`
3. Verify Content-Type header is `application/x-www-form-urlencoded`

### Error: "Invalid scope"
**Fix**: The Cognito app client needs to be configured with the `iqq-api/read` scope. Contact your AWS administrator.

## Alternative: Use cURL

If Postman continues to have issues, use cURL which always works:

```bash
# Set your secret
CLIENT_SECRET="your-secret-here"

# Get token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "25oa5u3vup2jmhl270e7shudkl:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

echo "Token: $TOKEN"

# Test package endpoint
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH" | jq .
```

## Quick Checklist

- [ ] Imported `postman-collection-fixed.json`
- [ ] Imported `postman-environment.json`
- [ ] Selected "iQQ Dev Environment" in dropdown
- [ ] Set `clientSecret` in environment
- [ ] Used "Get OAuth Token (Working)" request
- [ ] Checked Postman Console for success messages
- [ ] Verified `accessToken` is set in environment
- [ ] Tested an API endpoint successfully

## Need More Help?

See the full troubleshooting guide: [POSTMAN_TROUBLESHOOTING.md](./POSTMAN_TROUBLESHOOTING.md)
