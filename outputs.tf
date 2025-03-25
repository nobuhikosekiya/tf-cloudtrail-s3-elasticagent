output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket where CloudTrail logs are stored"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the S3 bucket where CloudTrail logs are stored"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for S3 notifications"
  value       = aws_sqs_queue.cloudtrail_events.id
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue for S3 notifications"
  value       = aws_sqs_queue.cloudtrail_events.arn
}

output "elastic_agent_instance_id" {
  description = "Instance ID of the EC2 instance running Elastic Agent"
  value       = aws_instance.elastic_agent.id
}

output "elastic_agent_public_ip" {
  description = "Public IP address of the EC2 instance running Elastic Agent"
  value       = aws_instance.elastic_agent.public_ip
}

output "elastic_agent_private_ip" {
  description = "Private IP address of the EC2 instance running Elastic Agent"
  value       = aws_instance.elastic_agent.private_ip
}

output "elastic_agent_role_name" {
  description = "Name of the IAM role attached to the Elastic Agent EC2 instance"
  value       = aws_iam_role.elastic_agent.name
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}