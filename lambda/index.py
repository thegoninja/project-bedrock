import json
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda function to process S3 upload events.
    Logs the name of uploaded files to CloudWatch.
    """
    
    logger.info("Asset processor Lambda triggered")
    logger.info(f"Event: {json.dumps(event)}")
    
    # Process each record in the S3 event
    for record in event['Records']:
        # Get the bucket name and object key
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        # Log the image received message
        logger.info(f"Image received: {key}")
        logger.info(f"Bucket: {bucket}")
        logger.info(f"File size: {record['s3']['object']['size']} bytes")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Asset processing complete',
            'filesProcessed': len(event['Records'])
        })
    }
