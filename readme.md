# AWS CloudTrail to Elastic - Log Collection Infrastructure via S3-SQS

This Terraform configuration sets up an infrastructure to collect AWS CloudTrail logs and send them to Elastic Stack. The logs are stored in an S3 bucket, and notifications are sent to an SQS queue. An EC2 instance with appropriate IAM permissions is created for running Elastic Agent, but the agent installation and configuration will be done manually.

## Architecture

The setup includes:

1. **S3 Bucket**: Stores CloudTrail logs
2. **CloudTrail**: Configured to write logs to the S3 bucket
3. **SQS Queue**: Receives notifications when new logs are added to S3
4. **EC2 Instance**: Pre-configured with IAM permissions to access S3 and SQS
5. **IAM Roles & Policies**: Provides necessary permissions for log access

```
                 EXISTING SERVICES                 |            CREATED BY TERRAFORM
                                                   |
┌────────────────┐       ┌─────────────┐          |  ┌───────────────┐      ┌────────────────┐
│                │       │             │          |  │               │      │                │
│    AWS API     │ ───>  │  CloudTrail │ ────────>  │   S3 Bucket   │ ───> │   SQS Queue    │
│    Activity    │       │[CONFIGURED] │          |  │  [CREATED]    │      │   [CREATED]    │
│                │       │             │          |  │               │      │                │
└────────────────┘       └─────────────┘          |  └───────────────┘      └────────┬───────┘
                                                   |                                  │
                                                   |                                  │
                                                   |                                  ▼
┌───────────────┐                                  |  ┌────────────────┐    ┌─────────────────┐
│               │                                  |  │                │    │                 │
│  Elastic Cloud│ <─────────────────────────────────  │  EC2 Instance  │    │  IAM Roles &    │
│  [NOT CREATED]│                                  |  │   [CREATED]    │    │  Policies      │
│               │                                  |  │                │    │  [CREATED]      │
└───────────────┘                                  |  └────────────────┘    └─────────────────┘
                                                   |   * Elastic Agent is NOT installed
                                                   |     by this Terraform project
```

### Data Flow

1. AWS service API calls generate CloudTrail events
2. CloudTrail (created by this project) writes log files to the S3 bucket
3. S3 bucket (created by this project) sends notifications to the SQS queue when new objects are created
4. SQS queue (created by this project) holds notifications until they are processed
5. EC2 instance (created by this project) with Elastic Agent (must be installed manually) polls the SQS queue for notifications
6. Elastic Agent downloads the log files from S3 and processes them
7. Processed logs are sent to your Elastic deployment (not created by this project)

### Components Created by this Terraform Project

- ✅ CloudTrail trail configuration
- ✅ S3 bucket for storing CloudTrail logs with appropriate security settings
- ✅ SQS queue for S3 notifications
- ✅ EC2 instance with IAM roles for accessing S3 and SQS
- ✅ All necessary IAM roles and policies

### Components NOT Created by this Terraform Project

- ❌ Elastic Agent installation and configuration (must be done manually)
- ❌ Elastic Cloud deployment or any Elastic Stack components
- ❌ Any additional monitoring or alerting setup

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version >= 1.0)
- SSH key pair for EC2 access (located at `~/.ssh/id_rsa.pub`)

## Usage

1. Clone this repository
2. Create a `terraform.tfvars` file based on the example provided

### Initialization and Deployment

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Configuration

Edit the `terraform.tfvars` file to customize:

- AWS profile and region
- Resource prefix
- EC2 instance type and AMI
- Expiration date for resources
- VPC and subnet (optional)

### Manual Elastic Agent Installation

After infrastructure deployment, you'll need to:

1. SSH into the EC2 instance:
   ```bash
   ssh ec2-user@<instance-ip>
   ```

2. Install and configure Elastic Agent manually according to your requirements
   
3. Configure Elastic Agent to use the S3-SQS input. The key configuration details will be:
   - SQS Queue URL: Available in the Terraform outputs

## Customization

- **CloudTrail Configuration**: Modify the `aws_cloudtrail` resource in `main.tf` to change what events are captured
- **S3 Bucket Settings**: Adjust retention policies, encryption, etc. in `main.tf`
- **SQS Queue Settings**: Change message retention, visibility timeout, etc. in `main.tf`
- **EC2 Instance**: Change instance type, AMI, security group rules in `main.tf` and `variables.tf`

## Security Considerations

- **Networking**: The security group allows SSH access from anywhere by default. In production, restrict this to your IP range or VPN.
- **IAM Permissions**: The IAM role is configured with minimal permissions. Review and adjust as needed.
- **Data Protection**: S3 bucket is configured with encryption and public access blocking.
- **EC2 Security**: The EC2 instance is configured with IMDSv2 (requiring token for metadata access)

## Cleanup

```bash
terraform destroy
```

## Additional Resources

- [Elastic Agent AWS S3 Input Documentation](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-aws-s3.html)
- [AWS CloudTrail Documentation](https://docs.aws.amazon.com/cloudtrail/latest/userguide/cloudtrail-user-guide.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)