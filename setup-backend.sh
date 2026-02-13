#!/bin/bash

# Setup Script for Terraform Backend
# This creates the S3 bucket and DynamoDB table for Terraform state

set -e

echo "=== Setting up Terraform Backend ==="
echo ""

REGION="us-east-1"
BUCKET_NAME="project-bedrock-terraform-state"
DYNAMODB_TABLE="project-bedrock-terraform-locks"

# Create S3 bucket for state
echo "Creating S3 bucket for Terraform state..."
if [ "$REGION" = "us-east-1" ]; then
    # us-east-1 doesn't use LocationConstraint
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION 2>/dev/null || true
else
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION \
        --create-bucket-configuration LocationConstraint=$REGION 2>/dev/null || true
fi

# Wait a moment for bucket to be ready
sleep 2

# Enable versioning on the bucket
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block public access
echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION \
    --tags Key=Project,Value=barakat-2025-capstone 2>/dev/null || true

# Wait for table to be active
echo "Waiting for DynamoDB table to be active..."
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $REGION

echo ""
echo "✓ Terraform backend setup complete!"
echo ""
echo "Backend Configuration:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  Region: $REGION"
echo ""
echo "You can now run 'terraform init' in the terraform directory"
