output "s3_bucket_name" {
  description = "Name of the S3 bucket containing CloudTrail logs"
  value       = aws_s3_bucket.logs.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket containing CloudTrail logs"
  value       = aws_s3_bucket.logs.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for S3 notifications"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue for S3 notifications"
  value       = aws_sqs_queue.notifications.arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance for Elastic Agent"
  value       = aws_instance.elastic_agent.id
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.elastic_agent.public_ip
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.elastic_agent.private_ip
}

output "iam_role_name" {
  description = "Name of the IAM role for Elastic Agent"
  value       = aws_iam_role.elastic_agent.name
}

output "test_command" {
  description = "Full command to run the test script"
  value       = "python test_cloudtrail_s3_sqs.py --bucket ${aws_s3_bucket.logs.id} --queue-url ${aws_sqs_queue.notifications.url} --trail-name ${aws_cloudtrail.main.name} --region ${var.aws_region}"
}