# Project Bedrock - Detailed Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Infrastructure Deployment](#infrastructure-deployment)
4. [Application Deployment](#application-deployment)
5. [Verification](#verification)
6. [Developer Access](#developer-access)
7. [CI/CD Setup](#cicd-setup)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

Install the following tools before beginning:

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Terraform 1.6.0+
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### AWS Credentials

Configure AWS credentials with appropriate permissions:

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

## Initial Setup

### 1. Clone Repository

```bash
git clone <your-repository-url>
cd project-bedrock
```

### 2. Customize Variables

Edit `terraform/variables.tf`:

```hcl
variable "assets_bucket_name" {
  default = "bedrock-assets-john-doe-12345"  # Make globally unique!
}

variable "student_id" {
  default = "john-doe-12345"
}
```

### 3. Setup Terraform Backend

The backend stores state in S3 with DynamoDB locking:

```bash
./setup-backend.sh
```

Expected output:
```
=== Setting up Terraform Backend ===
Creating S3 bucket for Terraform state...
Enabling versioning on S3 bucket...
Enabling encryption on S3 bucket...
Blocking public access on S3 bucket...
Creating DynamoDB table for state locking...
✓ Terraform backend setup complete!
```

## Infrastructure Deployment

### Initialize Terraform

```bash
cd terraform
terraform init
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!
Terraform has been successfully initialized!
```

### Review Plan

```bash
terraform plan
```

Review the resources to be created:
- 1 VPC with 2 public and 2 private subnets
- 1 EKS cluster
- 2 managed node groups
- 1 S3 bucket
- 1 Lambda function
- IAM roles and policies
- CloudWatch log groups

### Apply Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

Deployment takes approximately 15-20 minutes.

### Save Outputs

```bash
# View all outputs
terraform output

# Save credentials (sensitive)
terraform output developer_access_key_id
terraform output developer_secret_access_key

# Generate grading file
terraform output -json > grading.json
```

## Application Deployment

### Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
```

Verify:
```bash
kubectl get nodes
```

Expected output:
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
```

### Deploy Application

Option 1: Automated Script
```bash
cd ..
./deploy.sh
```

Option 2: Manual Deployment
```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Add Helm repo
helm repo add aws-samples https://aws.github.io/retail-store-sample-app/
helm repo update

# Install application
helm upgrade --install retail-store aws-samples/retail-store-sample-app \
    --namespace retail-app \
    --values k8s/values.yaml \
    --wait \
    --timeout 10m
```

### Monitor Deployment

```bash
# Watch pod creation
kubectl get pods -n retail-app --watch

# Check all pods are running
kubectl get pods -n retail-app

# View services
kubectl get svc -n retail-app
```

Expected: All pods in `Running` status with `READY 1/1`

## Verification

### 1. Check Infrastructure

```bash
# EKS Cluster
aws eks describe-cluster --name project-bedrock-cluster --region us-east-1

# S3 Bucket
aws s3 ls | grep bedrock-assets

# Lambda Function
aws lambda get-function --function-name bedrock-asset-processor --region us-east-1

# CloudWatch Log Groups
aws logs describe-log-groups --log-group-name-prefix /aws/eks/project-bedrock --region us-east-1
```

### 2. Check Application

```bash
# All pods healthy
kubectl get pods -n retail-app

# Application logs
kubectl logs -n retail-app -l app=ui --tail=20

# Describe a pod
kubectl describe pod -n retail-app -l app=catalog | head -50
```

### 3. Test Event-Driven Pipeline

```bash
# Upload test file to S3
echo "Test image content" > test-image.jpg
aws s3 cp test-image.jpg s3://bedrock-assets-YOUR-STUDENT-ID/

# Check Lambda execution
aws logs tail /aws/lambda/bedrock-asset-processor --follow

# Expected: "Image received: test-image.jpg"
```

### 4. Access Application

```bash
# Port forward UI service
kubectl port-forward -n retail-app svc/ui 8080:80

# Open browser to http://localhost:8080
```

### 5. View CloudWatch Logs

Control Plane:
```bash
aws logs tail /aws/eks/project-bedrock-cluster/cluster --follow
```

Application:
```bash
# View in Console: CloudWatch → Log Groups → /aws/containerinsights/project-bedrock-cluster/application
```

## Developer Access

### Get Credentials

```bash
cd terraform

# Access Key ID
terraform output developer_access_key_id

# Secret (sensitive)
terraform output -raw developer_secret_access_key
```

### Test Read-Only Access

```bash
# Configure with developer credentials
export AWS_ACCESS_KEY_ID="<access-key-id>"
export AWS_SECRET_ACCESS_KEY="<secret-access-key>"

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster

# Test read access (should succeed)
kubectl get pods -n retail-app
kubectl get deployments -n retail-app
kubectl describe pod <pod-name> -n retail-app

# Test write access (should fail)
kubectl delete pod <pod-name> -n retail-app
# Expected: Error from server (Forbidden): pods "xxx" is forbidden
```

### Test S3 Access

```bash
# Upload to assets bucket (should succeed)
echo "test" > test.txt
aws s3 cp test.txt s3://bedrock-assets-YOUR-STUDENT-ID/

# List bucket (should succeed)
aws s3 ls s3://bedrock-assets-YOUR-STUDENT-ID/
```

### Test Console Access

1. Create password for IAM user:
```bash
aws iam create-login-profile \
    --user-name bedrock-dev-view \
    --password <secure-password> \
    --password-reset-required
```

2. Get console URL:
```bash
echo "https://<account-id>.signin.aws.amazon.com/console"
```

3. Login and verify:
   - Can view EKS cluster
   - Can view EC2 instances
   - Cannot modify resources

## CI/CD Setup

### 1. Create GitHub Repository

```bash
# Initialize git (if not done)
git init
git add .
git commit -m "Initial commit"

# Create repo on GitHub, then:
git remote add origin https://github.com/<username>/project-bedrock.git
git push -u origin main
```

### 2. Configure GitHub Secrets

1. Go to: Repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add:
   - Name: `AWS_ACCESS_KEY_ID`
     Value: Your AWS access key
   - Name: `AWS_SECRET_ACCESS_KEY`
     Value: Your AWS secret key

### 3. Test Pipeline

Create a pull request:
```bash
git checkout -b test-change
echo "# Test" >> terraform/README.md
git add terraform/README.md
git commit -m "Test CI/CD"
git push origin test-change
```

On GitHub:
1. Create PR from `test-change` to `main`
2. Verify workflow runs
3. Check for plan comment on PR
4. Merge PR
5. Verify apply workflow runs

### 4. Monitor Workflows

Go to: Repository → Actions

Verify:
- ✓ Terraform Plan runs on PR
- ✓ Plan output commented on PR
- ✓ Terraform Apply runs on merge
- ✓ grading.json artifact uploaded

## Troubleshooting

### Terraform Issues

**State locked:**
```bash
# View lock
aws dynamodb get-item \
    --table-name project-bedrock-terraform-locks \
    --key '{"LockID":{"S":"project-bedrock-terraform-state/terraform.tfstate"}}'

# Force unlock if needed
terraform force-unlock <lock-id>
```

**Backend doesn't exist:**
```bash
# Run setup again
./setup-backend.sh

# Re-initialize
terraform init -reconfigure
```

### EKS Access Issues

**Cannot connect to cluster:**
```bash
# Verify cluster exists
aws eks list-clusters --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig \
    --region us-east-1 \
    --name project-bedrock-cluster

# Check permissions
aws eks describe-cluster \
    --name project-bedrock-cluster \
    --region us-east-1
```

**Permission denied:**
```bash
# Check IAM user/role
aws sts get-caller-identity

# Verify access entry
aws eks list-access-entries \
    --cluster-name project-bedrock-cluster \
    --region us-east-1
```

### Application Issues

**Pods not starting:**
```bash
# Check events
kubectl get events -n retail-app --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod <pod-name> -n retail-app

# Check logs
kubectl logs <pod-name> -n retail-app --previous

# Check node resources
kubectl top nodes
kubectl describe nodes
```

**ImagePullBackOff:**
```bash
# Verify node IAM role has ECR permissions
# Check pod events for specific error
kubectl describe pod <pod-name> -n retail-app
```

### Lambda Issues

**Not triggering:**
```bash
# Verify S3 notification
aws s3api get-bucket-notification-configuration \
    --bucket bedrock-assets-YOUR-STUDENT-ID

# Check Lambda permissions
aws lambda get-policy \
    --function-name bedrock-asset-processor

# Test invoke manually
aws lambda invoke \
    --function-name bedrock-asset-processor \
    --payload '{"Records":[{"s3":{"bucket":{"name":"test"},"object":{"key":"test.jpg"}}}]}' \
    response.json
```

**Function errors:**
```bash
# View recent logs
aws logs tail /aws/lambda/bedrock-asset-processor --follow

# Check latest invocation
aws lambda get-function \
    --function-name bedrock-asset-processor
```

### CloudWatch Logging Issues

**No logs appearing:**
```bash
# Verify add-on installed
kubectl get daemonset -n amazon-cloudwatch

# Check add-on status
aws eks describe-addon \
    --cluster-name project-bedrock-cluster \
    --addon-name amazon-cloudwatch-observability

# Verify log groups exist
aws logs describe-log-groups --region us-east-1
```

**Control plane logs missing:**
```bash
# Verify logging enabled
aws eks describe-cluster \
    --name project-bedrock-cluster \
    --query 'cluster.logging'

# Enable if needed
aws eks update-cluster-config \
    --name project-bedrock-cluster \
    --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

## Cost Management

### Estimated Costs

- EKS Cluster: $73/month
- EC2 (2x t3.medium): $60/month  
- NAT Gateway: $33/month
- CloudWatch: $5/month
- Other: $5/month
- **Total: ~$175/month**

### Monitor Costs

```bash
# View current month cost
aws ce get-cost-and-usage \
    --time-period Start=2026-02-01,End=2026-02-28 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --filter file://cost-filter.json
```

### Cleanup Resources

When done with project:

```bash
# Delete application
helm uninstall retail-store -n retail-app
kubectl delete namespace retail-app

# Destroy infrastructure
cd terraform
terraform destroy

# Remove backend (optional)
aws s3 rb s3://project-bedrock-terraform-state --force
aws dynamodb delete-table \
    --table-name project-bedrock-terraform-locks \
    --region us-east-1
```

## Validation Checklist

Before submission, verify:

- [ ] All resources in `us-east-1`
- [ ] EKS cluster named `project-bedrock-cluster`
- [ ] VPC named `project-bedrock-vpc`
- [ ] Application in `retail-app` namespace
- [ ] All pods `Running` with `READY 1/1`
- [ ] IAM user `bedrock-dev-view` exists
- [ ] Developer can `kubectl get pods -n retail-app`
- [ ] Developer cannot `kubectl delete pod`
- [ ] S3 bucket named correctly
- [ ] Lambda triggers on S3 upload
- [ ] CloudWatch logs visible
- [ ] CI/CD pipeline functional
- [ ] All resources tagged `Project: barakat-2025-capstone`
- [ ] `grading.json` generated and committed

## Next Steps

For bonus objectives:
1. [RDS Integration Guide](docs/RDS.md)
2. [ALB Ingress Setup](docs/ALB.md)
3. [TLS Certificate Configuration](docs/TLS.md)
