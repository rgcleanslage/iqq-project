# Postman Quick Fix - HTML Error

## Problem
Getting HTML error page instead of JSON when calling OAuth token endpoint.

## Quick Solution

### Option 1: Use the Alternative Request (Easiest)

1. In Postman, use the **"Get OAuth Token (Alternative)"** request
2. Make sure your environment has:
   - `clientId`: `YOUR_CLIENT_ID`
   - `clientSecret`: Your actual secret
3. Click **Send**
4. Done! The pre-request script handles encoding automatically

### Option 2: Encode Credentials Manually

1. **Open the credential encoder**:
   - Open `docs/api/credential-encoder.html` in your browser
   - Or use command line:
   ```bash
   echo -n "YOUR_CLIENT_ID:YOUR_SECRET" | base64
   ```

2. **Add to Postman environment**:
   - Variable: `base64ClientCredentials`
   - Value: (paste the base64 string)

3. **Use the regular "Get OAuth Token" request**
   - It will use the encoded credentials

### Option 3: Use cURL (Always Works)

```bash
CLIENT_SECRET="your-secret-here"

curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "YOUR_CLIENT_ID:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read"
```

Then copy the `access_token` and manually set it in Postman.

## Why This Happens

Postman's built-in Basic Auth sometimes doesn't work correctly with Cognito's OAuth endpoint. The solution is to manually encode the credentials as Base64 and send them in the Authorization header.

## Verify It Works

You should get this response:
```json
{
  "access_token": "eyJraWQiOiJxSW5UR2EyYnJBZXNLbTBpTFJUUW1wMDA3VStmejdQNVBqYXBGdGJCVGNNPSIsImFsZyI6IlJTMjU2In0...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

NOT this:
```html
<!DOCTYPE html><html lang="en">...An error was encountered...
```

## Still Having Issues?

See the full [Postman Troubleshooting Guide](./POSTMAN_TROUBLESHOOTING.md) for more solutions.
