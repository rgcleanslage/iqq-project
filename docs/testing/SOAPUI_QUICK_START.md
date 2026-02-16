# SoapUI Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Get OAuth Token

Run the token generator script:

```bash
./get-oauth-token.sh
```

This will display your access token. Copy it - you'll need it in Step 3.

**Example output:**
```
✅ Token retrieved successfully!

ACCESS TOKEN (copy this to SoapUI):
==========================================
eyJraWQiOiJxxx...your_token_here...xxx
==========================================
```

---

### Step 2: Import SoapUI Project

1. **Open SoapUI**
2. **File → Import Project**
3. **Select**: `iQQ-API-SoapUI-Project.xml`
4. **Click**: Import

You should now see "iQQ Insurance API" project in the left panel.

---

### Step 3: Add Authorization Header

For **each request** you want to test:

1. **Expand** the project tree: `iQQ Insurance API → iQQ API → [Resource] → [Method] → Request`
2. **Click** on the request (e.g., "Get Lender Request")
3. **Click** the **Headers** tab at the bottom
4. **Click** the **+** button to add a new header
5. **Enter**:
   - **Name**: `Authorization`
   - **Value**: `Bearer <paste_your_token_here>`

**Important**: Replace `<paste_your_token_here>` with the actual token from Step 1.

---

### Step 4: Test Your First Endpoint

1. **Open**: `Lender → GET Lender → Get Lender Request`
2. **Verify** the Authorization header is set (from Step 3)
3. **Click** the green **▶ (Play)** button
4. **Check** the response on the right side

**Expected Result**: You should see a 200 OK response with lender data in JSON format.

---

### Step 5: Test All Endpoints

Repeat Step 3 and 4 for all four services:

- ✅ **Lender** - `GET /lender?lenderId=LENDER-123`
- ✅ **Package** - `GET /package?packageId=PKG-456`
- ✅ **Product** - `GET /product?productId=PROD-789`
- ✅ **Document** - `GET /document?documentId=DOC-101`

---

## 📋 Quick Reference

### API Configuration

| Setting | Value |
|---------|-------|
| **Base URL** | `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev` |
| **Token URL** | `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token` |
| **Client ID** | `25oa5u3vup2jmhl270e7shudkl` |
| **Token Expiry** | 1 hour (3600 seconds) |

### Test Endpoints

| Service | Endpoint | Query Parameter |
|---------|----------|-----------------|
| Lender | `/lender` | `lenderId=LENDER-123` |
| Package | `/package` | `packageId=PKG-456` |
| Product | `/product` | `productId=PROD-789` |
| Document | `/document` | `documentId=DOC-101` |

### Expected Response Codes

| Scenario | Status Code |
|----------|-------------|
| Success | `200 OK` |
| Unauthorized (no token) | `401 Unauthorized` |
| Unauthorized (invalid token) | `403 Forbidden` |
| Not Found | `404 Not Found` |
| Server Error | `500 Internal Server Error` |

---

## 🔧 Troubleshooting

### Problem: 401 Unauthorized

**Cause**: Token is missing, expired, or invalid

**Solution**:
1. Run `./get-oauth-token.sh` to get a fresh token
2. Update the Authorization header in your request
3. Try again

### Problem: 403 Forbidden - "User is not authorized to access this resource"

**Cause**: This was an issue with the Lambda authorizer policy (now fixed)

**Solution**:
- ✅ This issue has been fixed! The authorizer now returns a wildcard policy
- If you still see this error, get a fresh token: `./get-oauth-token.sh`
- The authorizer caches policies for 5 minutes, so a new token will trigger a fresh authorization

### Problem: "Connection refused" or timeout

**Cause**: Network issue or incorrect URL

**Solution**:
1. Verify you're connected to the internet
2. Check the endpoint URL is correct
3. Try accessing the token URL in a browser to verify connectivity

### Problem: Token expired

**Cause**: Tokens expire after 1 hour

**Solution**:
1. Run `./get-oauth-token.sh` again
2. Copy the new token
3. Update all your requests with the new token

### Problem: Can't see response

**Cause**: Response panel might be hidden

**Solution**:
1. Look for the response on the right side of the request window
2. If not visible, try resizing the panels
3. Check the "Raw" tab to see the full HTTP response

---

## 📊 Testing Checklist

Use this checklist to verify your testing:

- [ ] OAuth token retrieved successfully
- [ ] SoapUI project imported
- [ ] Authorization header added to all requests
- [ ] Lender service returns 200 OK
- [ ] Package service returns 200 OK
- [ ] Product service returns 200 OK
- [ ] Document service returns 200 OK
- [ ] Response times are reasonable (< 2 seconds)
- [ ] JSON responses are well-formed
- [ ] All expected fields are present in responses

---

## 🎯 Next Steps

Once basic testing works:

1. **Add Assertions** - Validate response data automatically
2. **Create Test Suite** - Run all tests together
3. **Data-Driven Testing** - Use `soapui-test-data.csv` for multiple test cases
4. **Negative Testing** - Test error scenarios
5. **Performance Testing** - Load test with multiple concurrent users

See `SOAPUI_TESTING_GUIDE.md` for detailed instructions on these advanced topics.

---

## 📞 Need Help?

- **Full Guide**: See `SOAPUI_TESTING_GUIDE.md`
- **API Documentation**: See `API_TEST_RESULTS.md`
- **Deployment Info**: See `DEPLOYMENT_COMPLETE.md`

---

## 💡 Pro Tips

1. **Token Management**: Save your token in a project property for easy reuse across all requests
2. **Keyboard Shortcuts**: Use `Ctrl+Enter` (Windows) or `Cmd+Enter` (Mac) to send requests quickly
3. **Response Validation**: Always check both the status code AND the response body
4. **Token Refresh**: Set a reminder to refresh your token every 50 minutes
5. **Save Often**: SoapUI can crash - save your project frequently

---

**Happy Testing!** 🎉
