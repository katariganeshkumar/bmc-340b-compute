# Deployment Guide

This guide explains how to deploy the HIPAA-compliant BMC Application infrastructure using nested CloudFormation stacks.

## Architecture

The `main.yaml` template uses **nested stacks** to deploy modular components:

1. **KMSStack** - Creates KMS key for encryption (from `templates/kms.yaml`)
2. **LoggingStack** - Creates CloudWatch Log Groups and VPC Flow Logs (from `templates/logging.yaml`)
3. **SecurityGroupsStack** - Creates security groups for ALB and EC2 (from `templates/security-groups.yaml`)
4. **IAMStack** - Creates IAM roles and policies (from `templates/iam.yaml`)
5. **Main Stack** - Creates ALB, EC2 Launch Template, Auto Scaling Group, and CloudWatch Alarms

## Prerequisites

1. **S3 Bucket**: Create an S3 bucket to store the nested stack templates
2. **AWS CLI**: Configured with appropriate permissions
3. **Templates**: All template files in the `templates/` directory

## Step 1: Create S3 Bucket for Templates

```bash
# Create S3 bucket (replace with your bucket name)
aws s3 mb s3://your-cf-templates-bucket --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket your-cf-templates-bucket \
  --versioning-configuration Status=Enabled
```

## Step 2: Upload Templates to S3

```bash
# Upload all templates to S3
aws s3 cp templates/kms.yaml s3://your-cf-templates-bucket/templates/kms.yaml
aws s3 cp templates/logging.yaml s3://your-cf-templates-bucket/templates/logging.yaml
aws s3 cp templates/security-groups.yaml s3://your-cf-templates-bucket/templates/security-groups.yaml
aws s3 cp templates/iam.yaml s3://your-cf-templates-bucket/templates/iam.yaml
```

Or use the deployment script (see Step 4).

## Step 3: Update Parameter Files

Update your parameter file (`parameters.json` or environment-specific files) with:

1. Your VPC and subnet IDs
2. SSL Certificate ARN
3. **TemplateBucket**: Your S3 bucket name

Example:
```json
{
  "ParameterKey": "TemplateBucket",
  "ParameterValue": "your-cf-templates-bucket"
}
```

## Step 4: Deploy Using Deployment Script

The easiest way to deploy is using the provided `deploy.sh` script:

```bash
# Development
./deploy.sh bmc-hipaa-dev dev your-cf-templates-bucket

# Staging
./deploy.sh bmc-hipaa-staging staging your-cf-templates-bucket

# Production
./deploy.sh bmc-hipaa-prod prod your-cf-templates-bucket
```

The script will:
1. Upload templates to S3
2. Add TemplateBucket parameter
3. Create or update the CloudFormation stack
4. Wait for completion
5. Display stack outputs

## Step 5: Manual Deployment

If you prefer manual deployment:

### 1. Upload Templates to S3

```bash
BUCKET_NAME="your-cf-templates-bucket"
REGION="us-east-1"

aws s3 cp templates/kms.yaml s3://$BUCKET_NAME/templates/kms.yaml --region $REGION
aws s3 cp templates/logging.yaml s3://$BUCKET_NAME/templates/logging.yaml --region $REGION
aws s3 cp templates/security-groups.yaml s3://$BUCKET_NAME/templates/security-groups.yaml --region $REGION
aws s3 cp templates/iam.yaml s3://$BUCKET_NAME/templates/iam.yaml --region $REGION
```

### 2. Update Parameter File

Add TemplateBucket to your parameter file:

```bash
# Add TemplateBucket parameter
cat parameters.json | jq '. + [{"ParameterKey": "TemplateBucket", "ParameterValue": "your-cf-templates-bucket"}]' > parameters-with-bucket.json
```

### 3. Deploy Stack

```bash
aws cloudformation create-stack \
  --stack-name bmc-hipaa-autoscaling-alb \
  --template-body file://main.yaml \
  --parameters file://parameters-with-bucket.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Compliance,Value=HIPAA Key=Application,Value=BMC
```

## Updating Templates

When you update templates, you need to:

1. Upload updated templates to S3
2. Update the main stack (CloudFormation will detect changes)

```bash
# Upload updated templates
aws s3 cp templates/kms.yaml s3://your-cf-templates-bucket/templates/kms.yaml

# Update stack
aws cloudformation update-stack \
  --stack-name bmc-hipaa-autoscaling-alb \
  --template-body file://main.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

## Stack Dependencies

The nested stacks have the following dependencies:

```
KMSStack (no dependencies)
    ↓
LoggingStack (depends on KMSStack)
    ↓
IAMStack (depends on LoggingStack and KMSStack)
    ↓
SecurityGroupsStack (no dependencies, can run in parallel)
    ↓
ApplicationLoadBalancer (depends on SecurityGroupsStack)
    ↓
EC2LaunchTemplate (depends on IAMStack, SecurityGroupsStack, LoggingStack)
    ↓
AutoScalingGroup (depends on EC2LaunchTemplate and ALBTargetGroup)
```

## Troubleshooting

### Template Not Found Error

If you get "Template not found" errors:
- Verify templates are uploaded to S3
- Check the TemplateBucket parameter value
- Ensure TemplatePrefix matches your S3 folder structure

### Stack Update Failed

If nested stack update fails:
- Check nested stack events: `aws cloudformation describe-stack-events --stack-name <nested-stack-name>`
- Verify template syntax is valid
- Check IAM permissions for nested stack operations

### Permission Errors

Ensure your IAM user/role has:
- `cloudformation:*`
- `s3:GetObject`, `s3:PutObject` on template bucket
- `iam:*` (for creating roles and policies)
- `ec2:*`, `elasticloadbalancing:*`, `autoscaling:*`, `logs:*`, `kms:*`

## Benefits of Nested Stacks

1. **Modularity**: Each component can be updated independently
2. **Reusability**: Templates can be reused across different stacks
3. **Maintainability**: Easier to understand and modify individual components
4. **Isolation**: Failures in one nested stack don't affect others
5. **Versioning**: Templates in S3 can be versioned

## Next Steps

- Monitor stack events: `aws cloudformation describe-stack-events --stack-name <stack-name>`
- View stack outputs: `aws cloudformation describe-stacks --stack-name <stack-name>`
- Access EC2 instances via SSM Session Manager
- Monitor CloudWatch Logs for application logs
