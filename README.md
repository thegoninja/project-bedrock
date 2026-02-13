# Project Bedrock - InnovateMart EKS Deployment

## Overview

This repository contains the complete infrastructure-as-code solution for deploying InnovateMart's production-grade Kubernetes environment on AWS EKS, including the AWS Retail Store Sample Application.

## Quick Start

```bash
# 1. Setup Terraform backend
./setup-backend.sh

# 2. Deploy infrastructure
cd terraform
terraform init
terraform apply

# 3. Deploy application
cd ..
./deploy.sh

# 4. Generate grading output
cd terraform
terraform output -json > grading.json
```

## Documentation

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

## Architecture

- **VPC**: `project-bedrock-vpc` with public/private subnets across 2 AZs
- **EKS**: `project-bedrock-cluster` running Kubernetes 1.31
- **Application**: AWS Retail Store Sample App in `retail-app` namespace
- **Logging**: CloudWatch for control plane and container logs
- **IAM**: `bedrock-dev-view` user with read-only access
- **Event Processing**: S3 + Lambda for asset processing

## Repository Structure

```
project-bedrock/
├── terraform/          # Infrastructure as Code
├── lambda/            # Lambda function code
├── k8s/               # Kubernetes manifests
├── .github/workflows/ # CI/CD pipelines
├── setup-backend.sh   # Backend setup script
└── deploy.sh          # Application deployment
```

## Key Resources

All resources tagged with: `Project: barakat-2025-capstone`

## License

Educational project for Barakat Third Semester Exam.
