variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "prefix" {
  description = "Prefix for all resources created"
  type        = string
  default     = "cloudtrail-elastic"
}

variable "ec2_instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t3.medium"
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0599b6e53ca798bb2"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "logs"
}

variable "sqs_queue_name" {
  description = "Name for SQS queue"
  type        = string
  default     = "s3-notifications"
}

variable "lambda_log_level" {
  description = "Log level for Lambda function"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.lambda_log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR"
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}