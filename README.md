# HIPAA-Compliant EC2 Auto Scaling with Application Load Balancer for BMC Application

**Repository**: [https://github.com/katariganeshkumar/bmc-340b-compute](https://github.com/katariganeshkumar/bmc-340b-compute)

This CloudFormation template creates a HIPAA-compliant EC2 Auto Scaling Group with an Application Load Balancer (ALB) in private subnets with SSM Session Manager access, specifically configured for BMC applications handling Protected Health Information (PHI). **All EC2 instances use Ubuntu 22.04 LTS OS and t3.nano instance type.**

## Project Structure

```
compute/
├── main.yaml                    # Main CloudFormation template (orchestrates nested stacks)
├── deploy.sh                    # Deployment script
├── templates/                   # Reusable CloudFormation templates (nested stacks)
│   ├── kms.yaml                # KMS encryption template
│   ├── security-groups.yaml    # Security groups template
│   ├── iam.yaml                # IAM roles and policies template
│   ├── logging.yaml            # CloudWatch Logs and VPC Flow Logs template
│   ├── alb.yaml                # Application Load Balancer template
│   ├── ec2.yaml                # EC2 Launch Template
│   ├── autoscaling.yaml        # Auto Scaling Group template
│   └── README.md               # Templates documentation
├── environments/                # Environment-specific parameter files
│   ├── dev.json                # Development environment
│   ├── staging.json            # Staging environment
│   ├── prod.json               # Production environment
│   └── README.md               # Environments documentation
└── README.md                   # This file
```

### Key Files

- **`main.yaml`**: Main CloudFormation template that orchestrates nested stacks
- **`templates/`**: Individual template files deployed as nested stacks
  - `kms.yaml`: KMS encryption
  - `security-groups.yaml`: Security groups
  - `iam.yaml`: IAM roles and policies
  - `logging.yaml`: CloudWatch Logs and VPC Flow Logs
  - `alb.yaml`: Application Load Balancer, Target Group, Listeners
  - `ec2.yaml`: EC2 Launch Template
  - `autoscaling.yaml`: Auto Scaling Group, Scaling Policies, CloudWatch Alarms
- **`environments/`**: Environment-specific parameter files (dev/staging/prod)
- **`deploy.sh`**: Deployment script that uploads templates to S3 and deploys stack

## HIPAA Compliance Features

✅ **Encryption at Rest**: EBS volumes encrypted with KMS  
✅ **Encryption in Transit**: HTTPS/TLS 1.2+ enforced, HTTP redirects to HTTPS  
✅ **Access Controls**: EC2 instances in private subnets only, restricted security groups  
✅ **Audit Logging**: CloudWatch Logs for application and access logs (90-day retention)  
✅ **Network Monitoring**: VPC Flow Logs enabled for network traffic auditing  
✅ **Secure Access**: SSM Session Manager (no SSH keys or bastion hosts)  
✅ **Compliance Tagging**: HIPAA and BMC application tags on all resources  
✅ **Deletion Protection**: ALB deletion protection enabled  
✅ **Enhanced Security**: TLS 1.3 policy, invalid header dropping enabled  

## Architecture

- **Application Load Balancer**: Deployed in a single public subnet, internet-facing with HTTPS/TLS (Workload OU configuration)
- **EC2 Instances**: Deployed in private subnets only (no direct internet access)
  - **OS**: Ubuntu 22.04 LTS
  - **Instance Type**: t3.nano (default, configurable)
- **Auto Scaling Group**: Automatically scales EC2 instances based on CPU utilization
- **SSM Session Manager**: Used for secure access to EC2 instances (no SSH/bastion host needed)
- **Security Groups**: Configured to allow traffic from ALB to EC2 instances only
- **KMS Encryption**: All EBS volumes encrypted, CloudWatch Logs encrypted
- **Audit Logging**: Comprehensive logging for HIPAA compliance

## Prerequisites

1. **Existing VPC** with:
   - 1 public subnet (for ALB) - Workload OU configuration
   - 2 private subnets (for EC2 instances)
   - Internet Gateway attached to VPC
   - NAT Gateway or NAT Instance in public subnet (for EC2 instances to access internet)
   
   **Note**: ALB typically requires subnets in at least 2 Availability Zones for high availability. With a single public subnet, the ALB will still function but may have reduced availability if that AZ experiences issues.

2. **SSL Certificate** in AWS Certificate Manager (ACM):
   - Must be in the same region as your resources
   - Can be a public certificate or private certificate
   - Note the ARN for the `SSLCertificateARN` parameter

3. **AWS CLI** configured with appropriate permissions:
   - CloudFormation, EC2, ELB, IAM, KMS, CloudWatch Logs, VPC Flow Logs permissions

## Parameters

### Required Parameters

- **VpcId**: Your existing VPC ID
- **PrivateSubnet1Id**: First private subnet ID for EC2 instances
- **PrivateSubnet2Id**: Second private subnet ID for EC2 instances
- **PublicSubnet1Id**: Public subnet ID for ALB (single public subnet in Workload OU)
- **SSLCertificateARN**: ARN of SSL certificate in ACM (required for HTTPS)

### Optional Parameters

- **InstanceType**: EC2 instance type (default: **t3.nano**)
- **MinSize**: Minimum number of instances (default: 1)
- **MaxSize**: Maximum number of instances (default: 3)
- **DesiredCapacity**: Desired number of instances (default: 2)
- **AMIId**: Custom AMI ID (optional, defaults to latest Ubuntu 22.04 LTS)
- **AllowedCIDR**: CIDR block allowed to access ALB (default: 10.0.0.0/16 - **RESTRICT THIS FOR HIPAA**)
- **KMSKeyId**: Existing KMS Key ID for encryption (optional, creates new key if not provided)
- **EnableVPCFlowLogs**: Enable VPC Flow Logs (default: true, recommended for HIPAA)
- **TemplateBucketName**: S3 bucket name where nested stack templates are stored (required)

## Deployment

### 1. Create SSL Certificate in ACM

```bash
# Request a certificate in us-west-2 (if you don't have one)
aws acm request-certificate \
  --domain-name your-bmc-domain.com \
  --validation-method DNS \
  --region us-west-2

# List certificates to get ARN
aws acm list-certificates --region us-west-2
```

### 2. Create S3 Bucket for Templates

Nested stacks require templates to be stored in S3:

```bash
# Create S3 bucket in us-west-2 (replace with your bucket name)
aws s3 mb s3://your-cf-templates-bucket --region us-west-2

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket your-cf-templates-bucket \
  --versioning-configuration Status=Enabled \
  --region us-west-2
```

### 3. Get Subnet IDs

If you need to find your subnet IDs:

```bash
# List subnets in your VPC (us-west-2)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0ac6a3c566740c4bb" \
  --region us-west-2 \
  --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0],AvailabilityZone,CidrBlock]' \
  --output table

# Update environments/dev.json with the actual subnet IDs
```

### 3. Get Subnet IDs

If you need to find your subnet IDs:

```bash
# Use the helper script
./get-subnets.sh vpc-0ac6a3c566740c4bb us-west-2

# Or manually query
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0ac6a3c566740c4bb" \
  --region us-west-2 \
  --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0],AvailabilityZone,CidrBlock]' \
  --output table
```

### 4. Update Environment Parameters

Edit the appropriate environment file with your actual values:

**For Development (us-west-2):**
```bash
# Edit environments/dev.json
# VPC ID is already set: vpc-0ac6a3c566740c4bb
# Update subnet IDs and SSL certificate ARN
```

**For Staging:**
```bash
# Edit environments/staging.json
```

**For Production:**
```bash
# Edit environments/prod.json
```

```json
{
  "ParameterKey": "VpcId",
  "ParameterValue": "vpc-1234567890abcdef0"
},
{
  "ParameterKey": "SSLCertificateARN",
  "ParameterValue": "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
},
{
  "ParameterKey": "AllowedCIDR",
  "ParameterValue": "10.0.0.0/16"  // RESTRICT to your organization's IP range
}
```

**IMPORTANT**: For HIPAA compliance, restrict `AllowedCIDR` to your organization's IP range, not `0.0.0.0/0`.

### 4. Deploy Stack

**Option 1: Using Deployment Script (Recommended)**

```bash
# Development
./deploy.sh dev your-cf-templates-bucket

# Staging
./deploy.sh staging your-cf-templates-bucket

# Production
./deploy.sh prod your-cf-templates-bucket
```

**Option 2: Manual Deployment**

```bash
# 1. Upload templates to S3 (us-west-2)
aws s3 sync templates/ s3://your-cf-templates-bucket/templates/ \
  --exclude "*.md" --exclude "README.md" \
  --region us-west-2

# 2. Deploy stack (Development example - us-west-2)
aws cloudformation deploy \
  --template-file main.yaml \
  --stack-name bmc-hipaa-dev \
  --parameter-overrides file://environments/dev.json TemplateBucketName=your-cf-templates-bucket \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2 \
  --tags Compliance=HIPAA Application=BMC Environment=dev

# 3. For Staging (us-west-2)
aws cloudformation deploy \
  --template-file main.yaml \
  --stack-name bmc-hipaa-staging \
  --parameter-overrides file://environments/staging.json TemplateBucketName=your-cf-templates-bucket \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2 \
  --tags Compliance=HIPAA Application=BMC Environment=staging

# 4. For Production (us-west-2)
aws cloudformation deploy \
  --template-file main.yaml \
  --stack-name bmc-hipaa-prod \
  --parameter-overrides file://environments/prod.json TemplateBucketName=your-cf-templates-bucket \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2 \
  --tags Compliance=HIPAA Application=BMC Environment=prod
```

### 5. Update Stack (if needed)

```bash
# Update templates in S3 first
aws s3 sync templates/ s3://your-cf-templates-bucket/templates/ \
  --exclude "*.md" --exclude "README.md"

# Then update stack
aws cloudformation deploy \
  --template-file main.yaml \
  --stack-name bmc-hipaa-dev \
  --parameter-overrides file://environments/dev.json TemplateBucketName=your-cf-templates-bucket \
  --capabilities CAPABILITY_NAMED_IAM
```

### 6. Delete Stack

**Note**: ALB has deletion protection enabled. Disable it first:

```bash
# Update stack to disable deletion protection, then delete
aws cloudformation delete-stack --stack-name bmc-hipaa-autoscaling-alb
```

## Accessing EC2 Instances via SSM Session Manager

After deployment, connect to EC2 instances using AWS Systems Manager Session Manager:

```bash
# List all instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bmc-hipaa-autoscaling-alb-ec2-instance" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table

# Start a session (replace INSTANCE_ID with actual instance ID)
aws ssm start-session --target INSTANCE_ID
```

Or use the AWS Console:
1. Go to EC2 Console → Instances
2. Select your instance
3. Click "Connect" → "Session Manager" → "Connect"

## HIPAA Compliance Checklist

- [x] **Encryption at Rest**: EBS volumes encrypted with KMS
- [x] **Encryption in Transit**: HTTPS/TLS enforced, HTTP redirects to HTTPS
- [x] **Access Controls**: Private subnets, restricted security groups
- [x] **Audit Logging**: CloudWatch Logs with 90-day retention
- [x] **Network Monitoring**: VPC Flow Logs enabled
- [x] **Secure Access**: SSM Session Manager (no SSH)
- [x] **Compliance Tagging**: All resources tagged with HIPAA and BMC
- [x] **Deletion Protection**: ALB protected from accidental deletion
- [x] **Least Privilege**: IAM roles with minimal required permissions
- [x] **Monitoring**: CloudWatch alarms and metrics

## Outputs

After deployment, the stack will output:

- **LoadBalancerDNS**: DNS name of the ALB (use HTTPS:// to access)
- **LoadBalancerARN**: ARN of the ALB
- **TargetGroupARN**: ARN of the Target Group
- **AutoScalingGroupName**: Name of the Auto Scaling Group
- **EC2SecurityGroupId**: Security Group ID for EC2 instances
- **ALBSecurityGroupId**: Security Group ID for ALB
- **KMSKeyId**: KMS Key ID used for encryption
- **CloudWatchLogGroups**: Log groups for audit logging
- **HIPAAComplianceNote**: Summary of compliance features

## Security Best Practices

1. **Restrict AllowedCIDR**: Update `AllowedCIDR` parameter to your organization's IP range
2. **SSL Certificate**: Use a valid SSL certificate from ACM
3. **KMS Key**: Use a dedicated KMS key with proper key policies
4. **CloudWatch Logs**: Monitor logs regularly for security events
5. **VPC Flow Logs**: Review network traffic patterns
6. **SSM Session Manager**: Use IAM policies to restrict who can access instances
7. **Regular Updates**: Keep Ubuntu and application software updated
8. **Backup Strategy**: Implement backup strategy for application data
9. **Disaster Recovery**: Plan for disaster recovery scenarios
10. **Access Reviews**: Regularly review IAM roles and security groups

## Monitoring and Logging

### CloudWatch Log Groups Created:
- `/aws/alb/{stack-name}/access-logs` - ALB access logs
- `/aws/ec2/{stack-name}/application-logs` - EC2 application logs (Apache, system logs)
- `/aws/vpc/{stack-name}/flow-logs` - VPC Flow Logs

### CloudWatch Metrics:
- CPU utilization (scaling triggers)
- Custom metrics under `BMC/HIPAA` namespace

### Viewing Logs:

```bash
# View ALB access logs
aws logs tail /aws/alb/bmc-hipaa-autoscaling-alb/access-logs --follow

# View EC2 application logs
aws logs tail /aws/ec2/bmc-hipaa-autoscaling-alb/application-logs --follow

# View VPC Flow Logs
aws logs tail /aws/vpc/bmc-hipaa-autoscaling-alb/flow-logs --follow
```

## Notes

- The template uses **Ubuntu 22.04 LTS** AMI by default (SSM agent pre-installed via snap)
- If using a custom AMI, ensure SSM agent is installed and configured
- EC2 instances have CloudWatch Agent pre-configured for HIPAA audit logging
- Auto Scaling Group uses ELB health checks
- Security groups allow HTTP (80) and HTTPS (443) from ALB to EC2 only
- All EBS volumes are encrypted at rest
- HTTPS is enforced with TLS 1.3 policy
- HTTP traffic automatically redirects to HTTPS
- Default instance type is **t3.nano** (cost-effective for development/testing)

## Ubuntu-Specific Notes

- Uses `apt-get` package manager instead of `yum`
- Apache web server is `apache2` instead of `httpd`
- Log files are in `/var/log/apache2/` instead of `/var/log/httpd/`
- SSM Agent is installed via snap package
- System logs are in `/var/log/syslog` and `/var/log/auth.log`

## Support

For BMC application-specific configuration, update the UserData section in the Launch Template to deploy your BMC application instead of the default Apache setup.
