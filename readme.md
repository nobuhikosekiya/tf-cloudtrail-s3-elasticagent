# AWS CloudTrail to Elastic Stack with S3-SQS Monitoring

This Terraform project sets up the infrastructure required for collecting AWS CloudTrail logs and sending them to Elastic Stack using Elastic Agent. The project configures CloudTrail, creates an S3 bucket for storing logs, sets up an SQS queue for notifications, and provisions an EC2 instance with the necessary IAM permissions to run Elastic Agent.

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌───────────────┐     ┌───────────────┐
│                 │     │              │     │               │     │               │
│   AWS Service   │────>│  CloudTrail  │────>│   S3 Bucket   │────>│   SQS Queue   │
│     Activity    │     │              │     │               │     │               │
│                 │     └──────────────┘     └───────────────┘     └───────┬───────┘
└─────────────────┘                                                        │
                                                                           │
                                                                           ▼
                                                          ┌────────────────────────────┐
                                                          │                            │
                                                          │  EC2 Instance with IAM     │
                                                          │  Permissions for SQS & S3  │
                                                          │                            │
                                                          └─────────────┬──────────────┘
                                                                        │
                                                                        │
                                                                        ▼
                                                          ┌────────────────────────────┐
                                                          │                            │
                                                          │      Elastic Stack         │
                                                          │     (Not provisioned       │
                                                          │      by this project)      │
                                                          │                            │
                                                          └────────────────────────────┘
```

## Components Created

1. **CloudTrail** - Configured to log all AWS API calls across all regions
2. **S3 Bucket** - Stores CloudTrail logs with proper encryption and access controls
3. **SQS Queue** - Receives notifications when new logs are added to S3
4. **EC2 Instance** - Pre-configured with IAM permissions to access S3 and SQS
5. **IAM Roles & Policies** - Provides necessary permissions for CloudTrail, S3, SQS, and EC2

## Prerequisites

- AWS CLI installed and configured
- Terraform 1.0.0 or newer
- SSH key pair (defaults to `~/.ssh/id_rsa.pub`)
- Proper AWS permissions to create and manage the resources

## Usage

### Quick Start

1. Clone this repository
2. Create a `terraform.tfvars` file based on the example provided
3. Initialize and apply the Terraform configuration:

```bash
terraform init
terraform plan
terraform apply
```

### Configuration Variables

Create a `terraform.tfvars` file to customize your deployment:

```hcl
aws_region  = "ap-northeast-1"
aws_profile = "default"
prefix      = "my-cloudtrail"

ec2_instance_type   = "t3.small"
ec2_ami_id          = "ami-0599b6e53ca798bb2"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

s3_bucket_prefix = "logs"
sqs_queue_name   = "s3-notifications"
lambda_log_level = "INFO"

default_tags = {
  division   = "platform"
  org        = "engineering"
  keep-until = "2026-01-01"
  team       = "observability"
  project    = "elastic-monitoring"
}
```

## Setting Up Elastic Agent

After the infrastructure is deployed, you'll need to:

1. SSH into the EC2 instance:
   ```bash
   ssh ec2-user@$(terraform output -raw ec2_public_ip)
   ```

2. Install and configure Elastic Agent (not included in this Terraform project)

3. Configure the Elastic Agent to use the S3-SQS input:
   ```yaml
   - type: aws-s3
     queue_url: <SQS_QUEUE_URL_FROM_TERRAFORM_OUTPUT>
     expand_event_list_from_field: Records
   ```

## Testing

A test script is included to verify the CloudTrail-S3-SQS flow is working correctly:

```bash
# Install dependencies
pip install -r requirements.txt

# Run the test script
python test_cloudtrail_s3_sqs.py \
  --bucket $(terraform output -raw s3_bucket_name) \
  --queue-url $(terraform output -raw sqs_queue_url) \
  --trail-name $(terraform output -raw cloudtrail_name)
```

The test script:
1. Verifies CloudTrail is properly configured
2. Generates some AWS API activity
3. Checks for CloudTrail logs in the S3 bucket
4. Confirms S3 notifications are arriving in the SQS queue

## CI/CD

This project includes GitHub Actions workflows for continuous integration and testing. The workflow:

1. Sets up the necessary AWS credentials and SSH key
2. Initializes and validates the Terraform configuration
3. Applies the Terraform configuration to create resources
4. Runs the test script to verify functionality
5. Cleans up all resources

To use the GitHub Actions workflow, you need to set the following repository secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `SSH_PRIVATE_KEY`
- `SSH_PUBLIC_KEY`

## Security Considerations

- The EC2 instance security group allows SSH access from any IP by default. For production, restrict this to specific IP ranges.
- S3 buckets are configured with server-side encryption and public access blocking.
- IAM roles follow the principle of least privilege, granting only the necessary permissions.

## Cleanup

To remove all resources created by this project:

```bash
terraform destroy
```

## Notes

- All S3 buckets are created with `force_destroy = true` to allow for easy cleanup, but be cautious in production environments as this can lead to data loss.
- The EC2 instance is configured with the minimum permissions required for Elastic Agent to interact with S3 and SQS.
- This project does not install or configure Elastic Agent or any Elastic Stack components.