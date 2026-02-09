#!/bin/bash
# Deployment script for HIPAA-Compliant BMC Application Infrastructure
# This script packages and deploys CloudFormation templates using nested stacks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="${1:-bmc-hipaa-autoscaling-alb}"
ENVIRONMENT="${2:-default}"
TEMPLATE_BUCKET="${3:-}"
REGION="${AWS_REGION:-us-east-1}"

# Check if TemplateBucket is provided
if [ -z "$TEMPLATE_BUCKET" ]; then
    echo -e "${RED}Error: TemplateBucket (S3 bucket name) is required${NC}"
    echo "Usage: $0 <stack-name> <environment> <template-bucket>"
    echo "Example: $0 bmc-hipaa-prod prod my-cf-templates-bucket"
    exit 1
fi

echo -e "${GREEN}Starting deployment...${NC}"
echo "Stack Name: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo "Template Bucket: $TEMPLATE_BUCKET"
echo "Region: $REGION"

# Determine parameter file
if [ "$ENVIRONMENT" = "dev" ] && [ -f "environments/dev.json" ]; then
    PARAM_FILE="environments/dev.json"
elif [ "$ENVIRONMENT" = "staging" ] && [ -f "environments/staging.json" ]; then
    PARAM_FILE="environments/staging.json"
elif [ "$ENVIRONMENT" = "prod" ] && [ -f "environments/prod.json" ]; then
    PARAM_FILE="environments/prod.json"
else
    PARAM_FILE="parameters.json"
fi

echo -e "${YELLOW}Using parameter file: $PARAM_FILE${NC}"

# Upload templates to S3
echo -e "${GREEN}Uploading templates to S3...${NC}"
aws s3 cp templates/kms.yaml s3://$TEMPLATE_BUCKET/templates/kms.yaml --region $REGION
aws s3 cp templates/logging.yaml s3://$TEMPLATE_BUCKET/templates/logging.yaml --region $REGION
aws s3 cp templates/security-groups.yaml s3://$TEMPLATE_BUCKET/templates/security-groups.yaml --region $REGION
aws s3 cp templates/iam.yaml s3://$TEMPLATE_BUCKET/templates/iam.yaml --region $REGION

# Add TemplateBucket parameter to parameter file
echo -e "${GREEN}Preparing parameters...${NC}"
TEMP_PARAM_FILE=$(mktemp)
cat $PARAM_FILE | jq ". + [{\"ParameterKey\": \"TemplateBucket\", \"ParameterValue\": \"$TEMPLATE_BUCKET\"}]" > $TEMP_PARAM_FILE

# Check if stack exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
    echo -e "${YELLOW}Stack exists, updating...${NC}"
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body file://main.yaml \
        --parameters file://$TEMP_PARAM_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --tags Key=Compliance,Value=HIPAA Key=Application,Value=BMC Key=Environment,Value=$ENVIRONMENT
    
    echo -e "${GREEN}Waiting for stack update to complete...${NC}"
    aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
else
    echo -e "${GREEN}Creating new stack...${NC}"
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://main.yaml \
        --parameters file://$TEMP_PARAM_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --tags Key=Compliance,Value=HIPAA Key=Application,Value=BMC Key=Environment,Value=$ENVIRONMENT
    
    echo -e "${GREEN}Waiting for stack creation to complete...${NC}"
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
fi

# Cleanup
rm -f $TEMP_PARAM_FILE

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Stack outputs:${NC}"
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs' --output table
