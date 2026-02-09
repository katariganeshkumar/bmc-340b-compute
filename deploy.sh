#!/bin/bash
# Deployment script for HIPAA-Compliant BMC Application Infrastructure
# This script uploads templates to S3 and deploys the CloudFormation stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
TEMPLATE_BUCKET=${2:-""}
STACK_NAME="bmc-hipaa-${ENVIRONMENT}"
REGION=${AWS_REGION:-us-east-1}

# Check if bucket is provided
if [ -z "$TEMPLATE_BUCKET" ]; then
    echo -e "${RED}Error: S3 bucket name is required${NC}"
    echo "Usage: $0 <environment> <s3-bucket-name>"
    echo "Example: $0 dev my-cf-templates-bucket"
    exit 1
fi

# Check if environment file exists
ENV_FILE="environments/${ENVIRONMENT}.json"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: Environment file ${ENV_FILE} not found${NC}"
    exit 1
fi

echo -e "${GREEN}Deploying BMC HIPAA Infrastructure${NC}"
echo "Environment: ${ENVIRONMENT}"
echo "Stack Name: ${STACK_NAME}"
echo "Template Bucket: ${TEMPLATE_BUCKET}"
echo "Region: ${REGION}"
echo ""

# Upload templates to S3
echo -e "${YELLOW}Uploading templates to S3...${NC}"
aws s3 sync templates/ s3://${TEMPLATE_BUCKET}/templates/ \
    --region ${REGION} \
    --exclude "*.md" \
    --exclude "README.md"

echo -e "${GREEN}Templates uploaded successfully${NC}"
echo ""

# Add TemplateBucketName to parameters
echo -e "${YELLOW}Preparing parameters...${NC}"
PARAMS=$(cat ${ENV_FILE} | jq --arg bucket "$TEMPLATE_BUCKET" '. + [{"ParameterKey": "TemplateBucketName", "ParameterValue": $bucket}]')

# Deploy stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file main.yaml \
    --stack-name ${STACK_NAME} \
    --parameter-overrides file://${ENV_FILE} TemplateBucketName=${TEMPLATE_BUCKET} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION} \
    --tags Compliance=HIPAA Application=BMC Environment=${ENVIRONMENT}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack deployed successfully!${NC}"
    echo ""
    echo "Getting stack outputs..."
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --region ${REGION} \
        --query 'Stacks[0].Outputs' \
        --output table
else
    echo -e "${RED}Stack deployment failed${NC}"
    exit 1
fi
