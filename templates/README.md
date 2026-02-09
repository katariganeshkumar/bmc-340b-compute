# Templates Directory

This directory contains reusable CloudFormation templates/components that can be used as nested stacks or referenced by the main template.

## Available Templates

### kms.yaml
KMS Key template for HIPAA-compliant encryption. Creates a KMS key and alias for encrypting EBS volumes and CloudWatch Logs.

**Parameters:**
- `StackName`: Stack name for resource naming
- `KMSKeyId`: Optional existing KMS Key ID

**Outputs:**
- `KMSKeyId`: KMS Key ID
- `KMSKeyArn`: KMS Key ARN

### security-groups.yaml
Security Groups template for ALB and EC2 instances with HIPAA-compliant rules.

**Parameters:**
- `StackName`: Stack name for resource naming
- `VpcId`: VPC ID
- `AllowedCIDR`: CIDR block allowed to access ALB

**Outputs:**
- `ALBSecurityGroupId`: ALB Security Group ID
- `EC2SecurityGroupId`: EC2 Security Group ID

### iam.yaml
IAM Roles and Policies template for EC2 instances with SSM and CloudWatch Logs permissions.

**Parameters:**
- `StackName`: Stack name for resource naming
- `EC2ApplicationLogsGroupArn`: ARN of EC2 Application Logs Group
- `KMSKeyArn`: ARN of KMS Key

**Outputs:**
- `EC2InstanceProfileArn`: EC2 Instance Profile ARN

### logging.yaml
CloudWatch Logging and VPC Flow Logs template for HIPAA audit compliance.

**Parameters:**
- `StackName`: Stack name for resource naming
- `VpcId`: VPC ID for VPC Flow Logs
- `KMSKeyId`: Optional KMS Key ID for encryption
- `EnableVPCFlowLogs`: Enable/disable VPC Flow Logs

**Outputs:**
- `ALBAccessLogsGroupName`: ALB Access Logs Group name
- `EC2ApplicationLogsGroupArn`: EC2 Application Logs Group ARN
- `EC2ApplicationLogsGroupName`: EC2 Application Logs Group name

## Usage as Nested Stacks

These templates can be deployed as nested stacks using AWS::CloudFormation::Stack:

```yaml
KMSStack:
  Type: AWS::CloudFormation::Stack
  Properties:
    TemplateURL: https://s3.amazonaws.com/your-bucket/templates/kms.yaml
    Parameters:
      StackName: !Ref AWS::StackName
      KMSKeyId: ''
```

## Standalone Usage

These templates can also be deployed independently:

```bash
aws cloudformation create-stack \
  --stack-name kms-template \
  --template-body file://templates/kms.yaml \
  --parameters ParameterKey=StackName,ParameterValue=my-stack
```
