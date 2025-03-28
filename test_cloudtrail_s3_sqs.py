#!/usr/bin/env python3
"""
Test script for CloudTrail S3 SQS notification flow
This script:
1. Generates AWS API activity by listing S3 buckets
2. Verifies CloudTrail is capturing events
3. Verifies S3 bucket is receiving log files
4. Verifies SQS queue is receiving notifications
5. Tests basic message reception from SQS
"""

import argparse
import boto3
import json
import time
import os
import logging
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('cloudtrail-s3-sqs-tester')

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Test CloudTrail S3 SQS notification flow')
    parser.add_argument('--bucket', required=True, help='S3 bucket name for CloudTrail logs')
    parser.add_argument('--queue-url', required=True, help='SQS queue URL for S3 notifications')
    parser.add_argument('--trail-name', required=True, help='CloudTrail trail name')
    parser.add_argument('--region', default='ap-northeast-1', help='AWS region')
    parser.add_argument('--profile', default=None, help='AWS profile name')
    parser.add_argument('--wait-time', type=int, default=300,
                        help='Time to wait for CloudTrail logs (seconds)')
    return parser.parse_args()

def get_aws_session(profile=None, region=None):
    """Create and return a boto3 session."""
    session = boto3.Session(profile_name=profile, region_name=region)
    return session

def generate_api_activity(session):
    """Generate AWS API activity that should be captured by CloudTrail."""
    logger.info("Generating AWS API activity...")
    s3_client = session.client('s3')
    
    # List buckets (this will be captured by CloudTrail)
    response = s3_client.list_buckets()
    logger.info(f"Listed {len(response['Buckets'])} S3 buckets")
    
    # Create and delete a test bucket to generate more events
    test_bucket_name = f"cloudtrail-test-{int(time.time())}"
    try:
        logger.info(f"Creating test bucket: {test_bucket_name}")
        s3_client.create_bucket(
            Bucket=test_bucket_name,
            CreateBucketConfiguration={'LocationConstraint': session.region_name}
        )
        time.sleep(5)
        logger.info(f"Deleting test bucket: {test_bucket_name}")
        s3_client.delete_bucket(Bucket=test_bucket_name)
    except ClientError as e:
        logger.warning(f"Error during test bucket operations: {e}")

def verify_cloudtrail_status(session, trail_name):
    """Verify CloudTrail is properly configured and logging."""
    logger.info(f"Verifying CloudTrail status for trail: {trail_name}")
    cloudtrail_client = session.client('cloudtrail')
    
    try:
        response = cloudtrail_client.get_trail_status(Name=trail_name)
        if response['IsLogging']:
            logger.info("CloudTrail is actively logging")
        else:
            logger.error("CloudTrail is NOT logging")
            return False
            
        # Check for any recent delivery errors
        if 'LatestDeliveryError' in response and response['LatestDeliveryError']:
            logger.error(f"CloudTrail delivery error: {response['LatestDeliveryError']}")
            return False
        
        return True
    except ClientError as e:
        logger.error(f"Error checking CloudTrail status: {e}")
        return False

def verify_s3_logs(session, bucket_name, wait_time=300):
    """Verify S3 bucket is receiving CloudTrail logs."""
    logger.info(f"Waiting for CloudTrail logs to appear in S3 bucket: {bucket_name}")
    s3_client = session.client('s3')
    
    # Start time
    start_time = time.time()
    found_logs = False
    
    while time.time() - start_time < wait_time:
        try:
            # Check for CloudTrail log files
            logger.info("Checking for CloudTrail log files...")
            response = s3_client.list_objects_v2(
                Bucket=bucket_name,
                Prefix='AWSLogs/',
                MaxKeys=10
            )
            
            if 'Contents' in response and len(response['Contents']) > 0:
                logger.info(f"Found {len(response['Contents'])} objects in the CloudTrail log bucket")
                found_logs = True
                break
            
            logger.info(f"No CloudTrail logs found yet. Waiting 30 seconds...")
            time.sleep(30)
        except ClientError as e:
            logger.error(f"Error checking S3 bucket: {e}")
            return False
    
    if not found_logs:
        logger.error(f"No CloudTrail logs found in S3 bucket after {wait_time} seconds")
        return False
    
    return True

def verify_sqs_notifications(session, queue_url, wait_time=300):
    """Verify SQS queue is receiving S3 notifications."""
    logger.info(f"Waiting for S3 notifications to appear in SQS queue: {queue_url}")
    sqs_client = session.client('sqs')
    
    # Start time
    start_time = time.time()
    found_notifications = False
    
    while time.time() - start_time < wait_time:
        try:
            # Check for messages in the queue
            logger.info("Checking for messages in SQS queue...")
            response = sqs_client.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20  # Long polling
            )
            
            if 'Messages' in response and len(response['Messages']) > 0:
                logger.info(f"Found {len(response['Messages'])} messages in the SQS queue")
                found_notifications = True
                
                # Print sample message
                try:
                    message = json.loads(response['Messages'][0]['Body'])
                    logger.info(f"Sample message: {json.dumps(message, indent=2)}")
                    
                    # Delete the message
                    receipt_handle = response['Messages'][0]['ReceiptHandle']
                    sqs_client.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=receipt_handle
                    )
                except Exception as e:
                    logger.warning(f"Error processing SQS message: {e}")
                
                break
            
            logger.info(f"No SQS notifications found yet. Waiting 30 seconds...")
            time.sleep(30)
        except ClientError as e:
            logger.error(f"Error checking SQS queue: {e}")
            return False
    
    if not found_notifications:
        logger.error(f"No S3 notifications found in SQS queue after {wait_time} seconds")
        return False
    
    return True

def main():
    """Main function."""
    args = parse_args()
    
    # Get AWS session
    session = get_aws_session(profile=args.profile, region=args.region)
    
    # Check components
    if not verify_cloudtrail_status(session, args.trail_name):
        logger.error("CloudTrail verification failed")
        return 1
    
    # Generate some API activity
    generate_api_activity(session)
    
    # Wait for and verify S3 logs
    if not verify_s3_logs(session, args.bucket, args.wait_time):
        logger.error("S3 log verification failed")
        return 1
    
    # Wait for and verify SQS notifications
    if not verify_sqs_notifications(session, args.queue_url, args.wait_time):
        logger.error("SQS notification verification failed")
        return 1
    
    logger.info("✅ All tests passed successfully!")
    return 0

if __name__ == "__main__":
    exit(main())