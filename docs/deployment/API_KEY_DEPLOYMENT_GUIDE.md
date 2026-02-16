# API Key + OAuth Deployment Guide

Complete guide to deploying and testing the dual authentication system (OAuth + API Keys).

## Overview

Your API now supports **both OAuth tokens and API keys** for maximum security and flexibility:

- **OAuth Token**: Provides authentication, authorization, and path-based access control
- **API Key**: Provides rate limiting, usage tracking, and client identification

## Current Configuration

### API Keys Created

1. **Default API Key** (Always created)
   - Purpose: Testing and development
   - Usage Plan: Standard (10K req/month, 50 req/sec)

2. **Partner A API Key** (Optional)
   - Purpose: Premium partner with higher limits
   - Usage Plan: Premium (100K req/month, 200 req/sec)

3. **Partner B API Key** (Optional)
   - Purpose: Standard partner
   - Usage Plan: Standard (10K req/month, 50 req/sec)

### Usage Plans

**Standard Plan:**
- 10,000 requests per month
- 50 requests per second
- 100 burst limit

**Premium Plan:**
- 100,000 requests per month
- 200 requests per second
- 500 burst limit

## Deployment Steps

### Phase 1: Deploy with Optional API Keys (Recommended First)

This allows existing clients to continue working while new clients can start using API keys.

**Step 1: Verify Configuration**

```bash
cd iqq-infrastructure/environments/dev
cat terraform.tfvars
```

Ensure these settings:
```hcl
api_key_required    = false  # Optional initially
create_partner_keys = true   # Create partner keys
```

**Step 2: Plan Deployment**

```bash
terraform plan
```

Expected changes:
- 3 API keys (default, partner_a, partner_b)
- 2 usage plans (standard, premium)
- 3 usage plan associations
- Updated API Gateway methods (api_key_required = false)

**Step 3: Apply Changes**

```bash
terraform apply
```

Type `yes` to confirm.

**Step 4: Retrieve API Keys**

```bash
cd ../../..
./get-api-keys.sh
```

Save the API keys securely. You'll need them for testing.

**Step 5: Test with API Key (Optional)**

```bash
# Test with default API key (auto-retrieved from Terraform)
./test-with-api-key.sh lender

# Test with specific API key
./test-with-api-key.sh lender YOUR_API_KEY_HERE
```

**Step 6: Test without API Key (Should Still Work)**

```bash
# Existing clients without API keys should still work
./get-oauth-token.sh
```

✅ **Phase 1 Complete**: API keys are available but not required.

---

### Phase 2: Require API Keys (Future)

Once all clients have API keys, make them required.

**Step 1: Update Configuration**

```bash
cd iqq-infrastructure/environments/dev
```

Edit `terraform.tfvars`:
```hcl
api_key_required    = true   # Now required!
create_partner_keys = true
```

**Step 2: Apply Changes**

```bash
terraform apply
```

**Step 3: Test**

```bash
cd ../../..

# With API key - should work
./test-with-api-key.sh lender

# Without API key - should fail with 403
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender?lenderId=LEND001" \
  -H "Authorization: Bearer $(./get-oauth-token.sh | grep 'Access Token' | cut -d' ' -f3)"
```

Expected: 403 Forbidden (missing API key)

✅ **Phase 2 Complete**: API keys are now required.

---

## Testing Guide

### Test 1: OAuth + API Key (Both)

```bash
./test-with-api-key.sh lender
```

Expected: ✅ 200 OK

### Test 2: OAuth Only (No API Key)

```bash
# Get OAuth token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "25oa5u3vup2jmhl270e7shudkl:oilctiluurgblk7212h8jb9lntjoefqb6n56rer3iuks9642el9" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Test without API key
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender?lenderId=LEND001" \
  -H "Authorization: Bearer $TOKEN"
```

Expected:
- If `api_key_required = false`: ✅ 200 OK
- If `api_key_required = true`: ❌ 403 Forbidden

### Test 3: API Key Only (No OAuth)

```bash
# Get API key
cd iqq-infrastructure/environments/dev
API_KEY=$(terraform output -raw default_api_key_value)
cd ../../..

# Test without OAuth token
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender?lenderId=LEND001" \
  -H "x-api-key: $API_KEY"
```

Expected: ❌ 401 Unauthorized (missing OAuth token)

### Test 4: Rate Limiting

```bash
# Send 100 requests rapidly (exceeds 50 req/sec limit)
for i in {1..100}; do
  ./test-with-api-key.sh lender &
done
wait
```

Expected: Some requests will receive 429 Too Many Requests

### Test 5: Different API Keys

```bash
# Test with Partner A key (premium plan)
cd iqq-infrastructure/environments/dev
PARTNER_A_KEY=$(terraform output -raw partner_a_api_key_value)
cd ../../..

./test-with-api-key.sh lender $PARTNER_A_KEY
```

Expected: ✅ 200 OK (with higher rate limits)

---

## SoapUI Integration

### Update SoapUI Project

**Step 1: Add API Key Header**

In SoapUI, for each request:

1. Open request editor
2. Go to "Headers" tab
3. Add header:
   - Name: `x-api-key`
   - Value: `${#Project#api_key}` (use project property)

**Step 2: Set Project Property**

1. Right-click project → Properties
2. Add custom property:
   - Name: `api_key`
   - Value: Your API key from `./get-api-keys.sh`

**Step 3: Test**

Run your test suite. All requests should now include both:
- `Authorization: Bearer <token>`
- `x-api-key: <key>`

---

## Monitoring and Analytics

### View Usage Metrics

**AWS Console:**

1. Go to API Gateway → Usage Plans
2. Select a usage plan (Standard or Premium)
3. Click "API Keys" tab
4. Select an API key
5. View metrics:
   - Requests per day
   - Throttled requests
   - Quota usage

**CloudWatch:**

```bash
# View API Gateway logs
aws logs tail /aws/apigateway/iqq-dev --follow
```

### Track Costs per API Key

**AWS Cost Explorer:**

1. Go to Cost Explorer
2. Filter by:
   - Service: API Gateway
   - Tag: API Key ID
3. View costs per partner

---

## Troubleshooting

### Issue 1: 403 Forbidden (Missing API Key)

**Symptom:**
```json
{"message": "Forbidden"}
```

**Cause:** API key required but not provided

**Solution:**
```bash
# Add x-api-key header
curl -H "x-api-key: YOUR_KEY" ...
```

### Issue 2: 403 Forbidden (Invalid API Key)

**Symptom:**
```json
{"message": "Forbidden"}
```

**Cause:** API key is invalid or disabled

**Solution:**
```bash
# Verify API key in AWS Console
aws apigateway get-api-keys --include-values
```

### Issue 3: 429 Too Many Requests

**Symptom:**
```json
{"message": "Too Many Requests"}
```

**Cause:** Exceeded rate limit or quota

**Solution:**
- Wait for rate limit to reset (1 second)
- Or upgrade to premium plan
- Or request quota increase

### Issue 4: 401 Unauthorized

**Symptom:**
```json
{"message": "Unauthorized"}
```

**Cause:** OAuth token missing or invalid

**Solution:**
```bash
# Get fresh OAuth token
./get-oauth-token.sh
```

### Issue 5: API Key Not Found in Terraform Output

**Symptom:**
```
Error: Output not found
```

**Cause:** Terraform hasn't been applied yet

**Solution:**
```bash
cd iqq-infrastructure/environments/dev
terraform apply
```

---

## Security Best Practices

### 1. Rotate API Keys Regularly

```bash
# Create new API key
aws apigateway create-api-key --name "partner-a-key-2024-02" --enabled

# Associate with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id <plan-id> \
  --key-id <new-key-id> \
  --key-type API_KEY

# Notify partner of new key
# After transition period, delete old key
aws apigateway delete-api-key --api-key <old-key-id>
```

### 2. Store API Keys Securely

- ✅ Use AWS Secrets Manager or Parameter Store
- ✅ Encrypt in transit (HTTPS only)
- ✅ Never commit to Git
- ❌ Don't log API keys
- ❌ Don't expose in client-side code

### 3. Monitor for Abuse

Set up CloudWatch alarms:

```bash
# Alert on high throttle rate
aws cloudwatch put-metric-alarm \
  --alarm-name "api-key-throttled" \
  --metric-name ThrottleCount \
  --namespace AWS/ApiGateway \
  --statistic Sum \
  --period 300 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

### 4. Use Different Keys per Environment

```
Dev:  iqq-partner-a-dev-key
Prod: iqq-partner-a-prod-key
```

Never use production keys in development.

### 5. Implement Key Expiration

While API Gateway doesn't support automatic expiration, implement a process:

1. Create keys with expiration date in name: `partner-a-2024-Q1`
2. Set calendar reminder to rotate
3. Notify partners 30 days before expiration
4. Create new key, transition, delete old key

---

## API Key Management Scripts

### Create New Partner Key

```bash
#!/bin/bash
# create-partner-key.sh

PARTNER_NAME=$1
PLAN_TYPE=${2:-standard}  # standard or premium

if [ -z "$PARTNER_NAME" ]; then
  echo "Usage: $0 <partner-name> [standard|premium]"
  exit 1
fi

# Add to Terraform
cat >> iqq-infrastructure/modules/api-gateway/main.tf <<EOF

resource "aws_api_gateway_api_key" "$PARTNER_NAME" {
  name        = "\${var.project_name}-$PARTNER_NAME-key-\${var.environment}"
  description = "API key for $PARTNER_NAME"
  enabled     = true
}

resource "aws_api_gateway_usage_plan_key" "$PARTNER_NAME" {
  key_id        = aws_api_gateway_api_key.$PARTNER_NAME.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.$PLAN_TYPE.id
}
EOF

echo "✅ Added $PARTNER_NAME to Terraform"
echo "Run: cd iqq-infrastructure/environments/dev && terraform apply"
```

### Disable Partner Key

```bash
#!/bin/bash
# disable-partner-key.sh

KEY_ID=$1

if [ -z "$KEY_ID" ]; then
  echo "Usage: $0 <api-key-id>"
  exit 1
fi

aws apigateway update-api-key \
  --api-key $KEY_ID \
  --patch-operations op=replace,path=/enabled,value=false

echo "✅ Disabled API key $KEY_ID"
```

---

## Next Steps

1. ✅ Deploy with `api_key_required = false` (Phase 1)
2. ✅ Test with `./test-with-api-key.sh`
3. ✅ Distribute API keys to partners
4. ✅ Monitor usage for 1-2 weeks
5. ⏳ Set `api_key_required = true` (Phase 2)
6. ⏳ Update SoapUI project with API keys
7. ⏳ Set up CloudWatch alarms
8. ⏳ Document key rotation process

---

## Summary

You now have a dual authentication system:

| Feature | OAuth Token | API Key | Both |
|---------|-------------|---------|------|
| Authentication | ✅ | ❌ | ✅ |
| Authorization | ✅ | ❌ | ✅ |
| Rate Limiting | ❌ | ✅ | ✅ |
| Usage Tracking | ❌ | ✅ | ✅ |
| Path Control | ✅ | ❌ | ✅ |
| Token Expiration | ✅ | ❌ | ✅ |

**Recommendation:** Use both for maximum security and control.

**Current Status:** API keys are optional (`api_key_required = false`)

**Next Action:** Run `terraform apply` to deploy API keys.
