# Get current account ID
data "aws_caller_identity" "current" {}

# Find default VPC and subnet if not specified
data "aws_vpc" "default" {
  default = true
  count   = var.vpc_id == null ? 1 : 0
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id == null ? data.aws_vpc.default[0].id : var.vpc_id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  count = var.subnet_id == null ? 1 : 0
}

locals {
  vpc_id    = var.vpc_id == null ? data.aws_vpc.default[0].id : var.vpc_id
  subnet_id = var.subnet_id == null ? tolist(data.aws_subnets.default[0].ids)[0] : var.subnet_id
  account_id = data.aws_caller_identity.current.account_id
  region = var.aws_region
}

# Create the S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.resource_prefix}-cloudtrail-logs-${local.account_id}"
  force_destroy = true
}

# Configure S3 bucket ACL
resource "aws_s3_bucket_acl" "cloudtrail" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudtrail]
  bucket = aws_s3_bucket.cloudtrail.id
  acl    = "private"
}

# Configure S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SQS queue for S3 notifications
resource "aws_sqs_queue" "cloudtrail_events" {
  name                      = "${var.resource_prefix}-cloudtrail-events"
  delay_seconds             = 0
  max_message_size          = 262144 # 256KB
  message_retention_seconds = 345600 # 4 days
  receive_wait_time_seconds = 20
  visibility_timeout_seconds = 300 # 5 minutes
  
  # Dead letter queue for failed messages
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.cloudtrail_events_dlq.arn
    maxReceiveCount     = 5
  })
}

# Dead letter queue for failed messages
resource "aws_sqs_queue" "cloudtrail_events_dlq" {
  name                      = "${var.resource_prefix}-cloudtrail-events-dlq"
  delay_seconds             = 0
  max_message_size          = 262144 # 256KB
  message_retention_seconds = 1209600 # 14 days
}

# S3 bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  # Explicit dependency to ensure bucket exists first
  depends_on = [
    aws_s3_bucket.cloudtrail,
    aws_s3_bucket_public_access_block.cloudtrail,
    aws_s3_bucket_ownership_controls.cloudtrail,
    aws_s3_bucket_acl.cloudtrail
  ]

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck20150319",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.cloudtrail.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite20150319",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.account_id}/*",
            "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
        },
        {
            "Sid": "AWSCloudTrailWrite20150319Global",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/aws-global/*",
            "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
        }
    ]
}
POLICY
}

# S3 event notification to SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.cloudtrail.id

  queue {
    queue_arn     = aws_sqs_queue.cloudtrail_events.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "AWSLogs/"
  }

  depends_on = [aws_sqs_queue_policy.cloudtrail_events]
}

# SQS policy to allow S3 to send notifications
resource "aws_sqs_queue_policy" "cloudtrail_events" {
  queue_url = aws_sqs_queue.cloudtrail_events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.cloudtrail_events.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.cloudtrail.arn
          }
        }
      }
    ]
  })
}

# CloudTrail configuration
resource "aws_cloudtrail" "main" {
  name                          = "${var.resource_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  
  # You can extend the event selectors to capture more events as needed
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  # Make sure all the S3 bucket configurations are applied first
  depends_on = [
    aws_s3_bucket.cloudtrail,
    aws_s3_bucket_policy.cloudtrail,
    aws_s3_bucket_public_access_block.cloudtrail,
    aws_s3_bucket_ownership_controls.cloudtrail,
    aws_s3_bucket_acl.cloudtrail
  ]
}

# EC2 Security Group
resource "aws_security_group" "elastic_agent" {
  name        = "${var.resource_prefix}-elastic-agent-sg"
  description = "Security group for Elastic Agent EC2 instance"
  vpc_id      = local.vpc_id

  # SSH access from anywhere (modify for production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

# IAM role for the EC2 instance
resource "aws_iam_role" "elastic_agent" {
  name = "${var.resource_prefix}-elastic-agent-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for EC2 to access SQS and S3
resource "aws_iam_policy" "elastic_agent" {
  name        = "${var.resource_prefix}-elastic-agent-policy"
  description = "Policy allowing EC2 to access SQS and S3 for CloudTrail logs"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "sqs:ReceiveMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*",
          aws_sqs_queue.cloudtrail_events.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "elastic_agent" {
  role       = aws_iam_role.elastic_agent.name
  policy_arn = aws_iam_policy.elastic_agent.arn
}

# EC2 instance profile
resource "aws_iam_instance_profile" "elastic_agent" {
  name = "${var.resource_prefix}-elastic-agent-profile"
  role = aws_iam_role.elastic_agent.name
}

# Import SSH key for EC2 instance
resource "aws_key_pair" "deployer" {
  key_name   = var.ec2_key_name
  public_key = file("~/.ssh/id_rsa.pub")
}

# EC2 instance for CloudTrail monitoring
resource "aws_instance" "elastic_agent" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.elastic_agent.id]
  subnet_id              = local.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.elastic_agent.name
  
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
  }
  
  tags = {
    Name = "${var.resource_prefix}-cloudtrail-monitor"
  }
}