variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "elastic-sa"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "resource_prefix" {
  description = "Prefix for all resources created"
  type        = string
  default     = "elastic-ct"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0599b6e53ca798bb2"
}

variable "ec2_instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t3.medium"
}

variable "ec2_key_name" {
  description = "Name for the EC2 key pair"
  type        = string
  default     = "elastic-agent-key"
}

variable "vpc_id" {
  description = "VPC ID to deploy resources"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID to deploy EC2 instance"
  type        = string
  default     = null
}

variable "default_tags" {
  description = "AWS default tags for resources"
  type        = map(string)
  default     = {}
}