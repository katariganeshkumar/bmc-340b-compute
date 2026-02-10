#!/bin/bash
# Helper script to get subnet IDs for a VPC

set -e

VPC_ID=${1:-vpc-0ac6a3c566740c4bb}
REGION=${2:-us-west-2}

echo "Getting subnets for VPC: ${VPC_ID} in region: ${REGION}"
echo ""

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
  --region ${REGION} \
  --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0],AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' \
  --output table

echo ""
echo "To update dev.json, use the SubnetId values:"
echo "- PublicSubnet1Id: Use subnet with MapPublicIpOnLaunch = True"
echo "- PrivateSubnet1Id: Use subnet with MapPublicIpOnLaunch = False (first private subnet)"
echo "- PrivateSubnet2Id: Use subnet with MapPublicIpOnLaunch = False (second private subnet)"
