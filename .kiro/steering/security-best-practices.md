---
inclusion: auto
description: Security best practices including secrets management, credential handling, code security, and AWS security guidelines
---

# Security Best Practices

Critical security guidelines for the iQQ Insurance Quoting Platform.

## Secrets Management

### NEVER Commit Secrets to Version Control

**CRITICAL**: Never commit any of the following to Git/GitHub:

❌ **Prohibited**:
- AWS access keys or secret keys
- API keys or tokens
- Database passwords
- Cognito client secrets
- Private keys or certificates
- OAuth tokens
- Encryption keys
- Any credentials or passwords

### Use AWS Secrets Manager

**Always** store secrets in AWS Secrets Manager:

```typescript
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({ region: 'us-east-1' });

async function getSecret(secretId: string): Promise<any> {
  const command = new GetSecretValueCommand({ SecretId: secretId });
  const response = await client.send(command);
  return JSON.parse(response.SecretString);
}

// Usage
const cognitoSecret = await getSecret('cognito-client-secret');
const clientSecret = cognitoSecret.client_secret;
```

### Environment Variables for Non-Secrets

Use environment variables for configuration (not secrets):

```yaml
# SAM template.yaml
Environment:
  Variables:
    ENVIRONMENT: dev
    TABLE_NAME: iqq-config-dev
    AWS_REGION: us-east-1
    LOG_LEVEL: INFO
```

**Good for environment variables**:
- Table names
- Region names
- Environment names (dev/prod)
- Feature flags
- Non-sensitive configuration

**Bad for environment variables**:
- Passwords
- API keys
- Access tokens
- Private keys

### GitHub Actions Secrets

Store secrets in GitHub Actions secrets (not in workflow files):

```yaml
# .github/workflows/deploy.yml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # ✅ From GitHub secrets
    aws-region: us-east-1
```

**Never do this**:
```yaml
# ❌ WRONG - hardcoded secret
- name: Configure AWS
  env:
    AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
    AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Template Files for Sensitive Data

Use `.template` files for examples:

```json
// postman-environment.template.json ✅
{
  "name": "iQQ API - Dev",
  "values": [
    {
      "key": "api_key",
      "value": "YOUR_API_KEY_HERE",
      "enabled": true
    }
  ]
}
```

Add actual files to `.gitignore`:
```
# .gitignore
postman-environment.json
.env
*.pem
*.key
secrets.json
```

## Credential Handling

### AWS Credentials

**Use IAM roles** (not access keys):

```yaml
# Lambda execution role
Policies:
  - DynamoDBCrudPolicy:
      TableName: !Ref TableName
  - Statement:
      - Effect: Allow
        Action: secretsmanager:GetSecretValue
        Resource: !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:*
```

**For GitHub Actions**, use OIDC (not access keys):

```terraform
# GitHub OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["..."]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:rgcleanslage/*:*"
        }
      }
    }]
  })
}
```

### OAuth Tokens

**Never log tokens**:

```typescript
// ❌ WRONG
console.log('Token:', event.headers.Authorization);

// ✅ CORRECT
console.log('Request received with authorization header');

// ✅ CORRECT - redact in logs
const token = event.headers.Authorization?.replace(/Bearer .+/, 'Bearer [REDACTED]');
console.log('Authorization:', token);
```

**Use short-lived tokens**:
- Access tokens: 1 hour TTL
- Refresh tokens: 30 days TTL
- Rotate regularly

**Validate tokens properly**:
```typescript
// Verify signature, issuer, audience, expiration
const verified = jwt.verify(token, signingKey, {
  algorithms: ['RS256'],
  audience: CLIENT_ID,
  issuer: `https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID}`,
  clockTolerance: 5 // Allow 5 seconds clock skew
});
```

### API Keys

**Rotate API keys regularly**:
```bash
# Create new API key
aws apigateway create-api-key --name "partner-a-key-2026-02" --enabled

# Associate with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id <plan-id> \
  --key-id <new-key-id> \
  --key-type API_KEY

# Notify partner of new key
# After transition period, delete old key
aws apigateway delete-api-key --api-key <old-key-id>
```

**Monitor API key usage**:
```bash
# Check usage
aws apigateway get-usage \
  --usage-plan-id <plan-id> \
  --start-date 2026-02-01 \
  --end-date 2026-02-28
```

## Code Security

### Input Validation

**Always validate and sanitize input**:

```typescript
// ✅ CORRECT
function validateProductCode(code: string): boolean {
  const validCodes = ['MBP', 'GAP', 'VSC', 'VDP'];
  return validCodes.includes(code);
}

function validateVehicleValue(value: any): number {
  const numValue = Number(value);
  if (isNaN(numValue) || numValue < 0 || numValue > 1000000) {
    throw new Error('Invalid vehicle value');
  }
  return numValue;
}

// Usage
const productCode = event.queryStringParameters?.productCode;
if (!productCode || !validateProductCode(productCode)) {
  return {
    statusCode: 400,
    body: JSON.stringify({ error: 'Invalid product code' })
  };
}
```

**Prevent injection attacks**:

```typescript
// ❌ WRONG - SQL injection risk (if using SQL)
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ CORRECT - parameterized query
const command = new GetCommand({
  TableName: TABLE_NAME,
  Key: { PK: `USER#${userId}`, SK: 'METADATA' }
});

// ❌ WRONG - command injection risk
exec(`ls ${userInput}`);

// ✅ CORRECT - validate input first
if (!/^[a-zA-Z0-9_-]+$/.test(userInput)) {
  throw new Error('Invalid input');
}
```

### Error Handling

**Don't expose internal details**:

```typescript
// ❌ WRONG - exposes stack trace
catch (error) {
  return {
    statusCode: 500,
    body: JSON.stringify({ 
      error: error.message,
      stack: error.stack  // ❌ Exposes internal details
    })
  };
}

// ✅ CORRECT - generic error message
catch (error) {
  console.error('Error processing request', { 
    error: error.message,
    stack: error.stack,
    correlationId 
  });
  
  return {
    statusCode: 500,
    body: JSON.stringify({ 
      error: 'Internal server error',
      correlationId  // ✅ For support tracking
    })
  };
}
```

### Dependency Security

**Keep dependencies updated**:

```bash
# Check for vulnerabilities
npm audit

# Fix vulnerabilities
npm audit fix

# Update dependencies
npm update

# Check for outdated packages
npm outdated
```

**Use package-lock.json**:
- Commit `package-lock.json` to Git
- Ensures consistent dependency versions
- Prevents supply chain attacks

**Review dependencies**:
- Only use well-maintained packages
- Check package reputation (downloads, stars, issues)
- Review package permissions
- Minimize dependencies

## AWS Security

### IAM Best Practices

**Principle of least privilege**:

```yaml
# ✅ CORRECT - specific permissions
Policies:
  - Statement:
      - Effect: Allow
        Action:
          - dynamodb:GetItem
          - dynamodb:Query
        Resource: !Sub arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/iqq-config-dev

# ❌ WRONG - overly permissive
Policies:
  - Statement:
      - Effect: Allow
        Action: dynamodb:*
        Resource: "*"
```

**Use resource-based policies**:

```yaml
# Restrict Lambda to specific API Gateway
SourceArn: !Sub arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGatewayId}/*
```

**Enable MFA for sensitive operations**:
- Root account access
- IAM user creation
- Security credential changes

### Encryption

**Encrypt data at rest**:

```terraform
# DynamoDB encryption
resource "aws_dynamodb_table" "config" {
  name = "iqq-config-dev"
  
  server_side_encryption {
    enabled = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
}

# S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Encrypt data in transit**:
- Always use HTTPS (not HTTP)
- TLS 1.2 or higher
- Valid SSL certificates

```terraform
# API Gateway - enforce HTTPS
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "dev"
  
  # Enforce TLS 1.2
  # API Gateway automatically enforces HTTPS
}
```

### CloudWatch Logs Security

**Don't log sensitive data**:

```typescript
// ❌ WRONG
console.log('User data:', {
  ssn: user.ssn,
  creditCard: user.creditCard,
  password: user.password
});

// ✅ CORRECT
console.log('User data:', {
  userId: user.id,
  email: user.email.replace(/(.{2}).*(@.*)/, '$1***$2'),  // Redact email
  // Omit sensitive fields
});
```

**Encrypt log data**:

```terraform
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/iqq-lender-dev"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn  # Encrypt logs
}
```

### Network Security

**Use VPC for sensitive resources** (if needed):

```yaml
# Lambda in VPC (for database access)
VpcConfig:
  SecurityGroupIds:
    - !Ref LambdaSecurityGroup
  SubnetIds:
    - !Ref PrivateSubnet1
    - !Ref PrivateSubnet2
```

**Security groups** (least privilege):

```terraform
resource "aws_security_group" "lambda" {
  name = "lambda-sg"
  
  # Only allow outbound HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## Monitoring & Auditing

### CloudTrail

**Enable CloudTrail** for audit logging:

```terraform
resource "aws_cloudtrail" "main" {
  name                          = "iqq-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

### CloudWatch Alarms

**Monitor security events**:

```terraform
# Alert on unauthorized API calls
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
}

# Alert on failed Lambda invocations
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
}
```

### Access Logging

**Enable API Gateway access logs**:

```terraform
resource "aws_api_gateway_stage" "dev" {
  # ... other config
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}
```

## Incident Response

### Security Incident Checklist

If a security incident occurs:

1. **Immediate Actions**:
   - [ ] Rotate compromised credentials immediately
   - [ ] Revoke compromised API keys
   - [ ] Review CloudTrail logs for unauthorized access
   - [ ] Check CloudWatch logs for suspicious activity

2. **Investigation**:
   - [ ] Identify scope of compromise
   - [ ] Review access patterns
   - [ ] Check for data exfiltration
   - [ ] Document timeline of events

3. **Remediation**:
   - [ ] Patch vulnerabilities
   - [ ] Update security policies
   - [ ] Implement additional monitoring
   - [ ] Notify affected parties (if required)

4. **Prevention**:
   - [ ] Conduct post-incident review
   - [ ] Update security procedures
   - [ ] Implement additional controls
   - [ ] Train team on lessons learned

### Emergency Credential Rotation

```bash
# Rotate Cognito client secret
aws cognito-idp update-user-pool-client \
  --user-pool-id us-east-1_Wau5rEb2N \
  --client-id 25oa5u3vup2jmhl270e7shudkl \
  --generate-secret

# Rotate API keys
aws apigateway create-api-key --name "emergency-key-$(date +%Y%m%d)" --enabled

# Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id cognito-client-secret \
  --secret-string '{"client_secret":"NEW_SECRET"}'

# Invalidate all sessions (if needed)
# This requires custom implementation
```

## Security Checklist

Before deploying:
- [ ] No secrets in code or config files
- [ ] All secrets in AWS Secrets Manager
- [ ] Environment variables don't contain secrets
- [ ] `.gitignore` includes sensitive files
- [ ] Input validation implemented
- [ ] Error messages don't expose internals
- [ ] Dependencies updated and audited
- [ ] IAM policies follow least privilege
- [ ] Encryption enabled (at rest and in transit)
- [ ] Logging doesn't include sensitive data
- [ ] CloudTrail enabled
- [ ] CloudWatch alarms configured
- [ ] API Gateway access logs enabled

## References

- #[[file:docs/api/SECRETS_MANAGEMENT.md]]
- #[[file:docs/deployment/GITHUB_OIDC_SETUP.md]]
- AWS Security Best Practices: https://aws.amazon.com/security/best-practices/
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- AWS Well-Architected Security Pillar: https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html
