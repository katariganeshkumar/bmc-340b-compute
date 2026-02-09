# Environments Directory

This directory contains environment-specific parameter files for different deployment environments.

## Available Environments

### dev.json
Development environment parameters:
- Smaller instance sizes (t3.nano)
- Lower capacity (Min: 1, Max: 2, Desired: 1)
- Development VPC and subnet IDs

### staging.json
Staging environment parameters:
- Medium instance sizes (t3.micro)
- Medium capacity (Min: 1, Max: 3, Desired: 2)
- Staging VPC and subnet IDs

### prod.json
Production environment parameters:
- Larger instance sizes (t3.small)
- Higher capacity (Min: 2, Max: 5, Desired: 3)
- Production VPC and subnet IDs

## Usage

Deploy to a specific environment:

```bash
# Development
aws cloudformation create-stack \
  --stack-name bmc-hipaa-dev \
  --template-body file://main.yaml \
  --parameters file://environments/dev.json \
  --capabilities CAPABILITY_NAMED_IAM

# Staging
aws cloudformation create-stack \
  --stack-name bmc-hipaa-staging \
  --template-body file://main.yaml \
  --parameters file://environments/staging.json \
  --capabilities CAPABILITY_NAMED_IAM

# Production
aws cloudformation create-stack \
  --stack-name bmc-hipaa-prod \
  --template-body file://main.yaml \
  --parameters file://environments/prod.json \
  --capabilities CAPABILITY_NAMED_IAM
```

## Customization

Update the parameter values in each environment file with your actual:
- VPC IDs
- Subnet IDs
- SSL Certificate ARNs
- KMS Key IDs (if using existing keys)
- Allowed CIDR blocks
