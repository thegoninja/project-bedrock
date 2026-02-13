# Quick Reference - Project Bedrock

## Essential Commands

### Initial Setup
```bash
# Clone repository
git clone <repo-url>
cd project-bedrock

# Setup Terraform backend
./setup-backend.sh

# Deploy infrastructure
cd terraform
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster

# Deploy application
cd ..
./deploy.sh
```

### Infrastructure Management

```bash
# Terraform operations
cd terraform
terraform plan                    # Preview changes
terraform apply                   # Apply changes
terraform destroy                 # Destroy all resources
terraform output                  # Show all outputs
terraform output -json > grading.json  # Generate grading file

# View specific outputs
terraform output cluster_endpoint
terraform output developer_access_key_id
terraform output -raw developer_secret_access_key
```

### Kubernetes Operations

```bash
# Cluster access
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
kubectl cluster-info
kubectl get nodes

# Namespace operations
kubectl get namespaces
kubectl get all -n retail-app

# Pod management
kubectl get pods -n retail-app
kubectl get pods -n retail-app -o wide
kubectl describe pod <pod-name> -n retail-app
kubectl logs <pod-name> -n retail-app
kubectl logs <pod-name> -n retail-app -f  # Follow logs

# Service operations
kubectl get svc -n retail-app
kubectl describe svc ui -n retail-app

# Deployment operations
kubectl get deployments -n retail-app
kubectl scale deployment ui --replicas=3 -n retail-app
kubectl rollout status deployment ui -n retail-app
kubectl rollout restart deployment ui -n retail-app
```

### Application Access

```bash
# Port forward to UI
kubectl port-forward -n retail-app svc/ui 8080:80

# Port forward to specific pod
kubectl port-forward -n retail-app <pod-name> 8080:8080

# Access in browser
open http://localhost:8080
```

### Developer Access Testing

```bash
# Configure with developer credentials
export AWS_ACCESS_KEY_ID="<access-key>"
export AWS_SECRET_ACCESS_KEY="<secret-key>"

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster

# Test read access (should work)
kubectl get pods -n retail-app
kubectl get deployments -n retail-app
kubectl describe pod <pod-name> -n retail-app
kubectl logs <pod-name> -n retail-app

# Test write access (should fail)
kubectl delete pod <pod-name> -n retail-app
kubectl scale deployment ui --replicas=5 -n retail-app
```

### S3 and Lambda Operations

```bash
# List S3 buckets
aws s3 ls

# Upload file to trigger Lambda
echo "test content" > test-image.jpg
aws s3 cp test-image.jpg s3://bedrock-assets-<student-id>/

# List bucket contents
aws s3 ls s3://bedrock-assets-<student-id>/

# View Lambda logs
aws logs tail /aws/lambda/bedrock-asset-processor --follow
aws logs tail /aws/lambda/bedrock-asset-processor --since 5m

# Invoke Lambda manually
aws lambda invoke \
    --function-name bedrock-asset-processor \
    --payload '{"Records":[{"s3":{"bucket":{"name":"test"},"object":{"key":"test.jpg"}}}]}' \
    response.json
cat response.json
```

### CloudWatch Logs

```bash
# List log groups
aws logs describe-log-groups --region us-east-1

# Control plane logs
aws logs tail /aws/eks/project-bedrock-cluster/cluster --follow

# Application logs
aws logs tail /aws/containerinsights/project-bedrock-cluster/application --follow

# Filter logs
aws logs filter-log-events \
    --log-group-name /aws/eks/project-bedrock-cluster/cluster \
    --filter-pattern "ERROR" \
    --start-time $(date -d '1 hour ago' +%s)000
```

### Troubleshooting

```bash
# Check cluster status
aws eks describe-cluster --name project-bedrock-cluster --region us-east-1

# Check node health
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes

# Check pod issues
kubectl get events -n retail-app --sort-by='.lastTimestamp'
kubectl describe pod <pod-name> -n retail-app
kubectl logs <pod-name> -n retail-app --previous  # Previous container logs

# Check resource usage
kubectl top pods -n retail-app
kubectl top nodes

# Check add-ons
kubectl get daemonset -n amazon-cloudwatch
aws eks describe-addon \
    --cluster-name project-bedrock-cluster \
    --addon-name amazon-cloudwatch-observability

# Check IAM
aws iam get-user --user-name bedrock-dev-view
aws iam list-attached-user-policies --user-name bedrock-dev-view
aws sts get-caller-identity

# Check S3 notifications
aws s3api get-bucket-notification-configuration \
    --bucket bedrock-assets-<student-id>

# Check Lambda permissions
aws lambda get-policy --function-name bedrock-asset-processor
```

### Helm Operations

```bash
# List releases
helm list -A

# Get release status
helm status retail-store -n retail-app

# View values
helm get values retail-store -n retail-app

# Upgrade release
helm upgrade retail-store aws-samples/retail-store-sample-app \
    -n retail-app \
    -f k8s/values.yaml

# Rollback release
helm rollback retail-store -n retail-app

# Uninstall release
helm uninstall retail-store -n retail-app
```

### Resource Tagging

```bash
# List resources with specific tag
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=barakat-2025-capstone \
    --region us-east-1

# Tag specific resource
aws eks tag-resource \
    --resource-arn <cluster-arn> \
    --tags Project=barakat-2025-capstone
```

### CI/CD Operations

```bash
# View GitHub Actions workflows
gh workflow list

# View workflow runs
gh run list

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>

# Trigger workflow manually
gh workflow run terraform.yml
```

### Backup and Export

```bash
# Export all resources
kubectl get all -n retail-app -o yaml > backup-retail-app.yaml

# Export specific resource
kubectl get deployment ui -n retail-app -o yaml > ui-deployment.yaml

# Backup Terraform state
cd terraform
terraform state pull > backup-state.json

# Export Helm values
helm get values retail-store -n retail-app > current-values.yaml
```

### Cost Management

```bash
# View current costs
aws ce get-cost-and-usage \
    --time-period Start=2026-02-01,End=2026-02-28 \
    --granularity DAILY \
    --metrics BlendedCost

# List running EC2 instances
aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=barakat-2025-capstone" \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' \
    --output table

# List EBS volumes
aws ec2 describe-volumes \
    --filters "Name=tag:Project,Values=barakat-2025-capstone" \
    --query 'Volumes[*].[VolumeId,Size,State]' \
    --output table
```

### Cleanup

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

## Common Issues and Fixes

### Issue: kubectl can't connect
```bash
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
kubectl get nodes
```

### Issue: Pods not starting
```bash
kubectl describe pod <pod-name> -n retail-app
kubectl logs <pod-name> -n retail-app
kubectl get events -n retail-app --sort-by='.lastTimestamp'
```

### Issue: Terraform state locked
```bash
terraform force-unlock <lock-id>
```

### Issue: No CloudWatch logs
```bash
aws eks describe-addon \
    --cluster-name project-bedrock-cluster \
    --addon-name amazon-cloudwatch-observability
```

### Issue: Lambda not triggering
```bash
aws s3api get-bucket-notification-configuration \
    --bucket bedrock-assets-<student-id>
aws lambda get-policy --function-name bedrock-asset-processor
```

## Useful URLs

```bash
# Get AWS Console login URL
echo "https://$(aws sts get-caller-identity --query Account --output text).signin.aws.amazon.com/console"

# Get EKS Console URL
echo "https://us-east-1.console.aws.amazon.com/eks/home?region=us-east-1#/clusters/project-bedrock-cluster"

# Get CloudWatch Logs URL
echo "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups"

# Get S3 Console URL
echo "https://s3.console.aws.amazon.com/s3/buckets/bedrock-assets-<student-id>?region=us-east-1"

# Get Lambda Console URL
echo "https://us-east-1.console.aws.amazon.com/lambda/home?region=us-east-1#/functions/bedrock-asset-processor"
```

## Environment Variables

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_DEFAULT_REGION="us-east-1"

# Set student ID
export STUDENT_ID="<your-student-id>"

# Use in commands
aws s3 ls s3://bedrock-assets-${STUDENT_ID}/
```

## Validation Commands

```bash
# Verify all core requirements
echo "=== Infrastructure ==="
aws eks describe-cluster --name project-bedrock-cluster --query 'cluster.name'
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=project-bedrock-vpc" --query 'Vpcs[0].VpcId'

echo "=== Application ==="
kubectl get pods -n retail-app

echo "=== Security ==="
aws iam get-user --user-name bedrock-dev-view

echo "=== Observability ==="
aws logs describe-log-groups --log-group-name-prefix /aws/eks/project-bedrock

echo "=== Serverless ==="
aws s3 ls | grep bedrock-assets
aws lambda get-function --function-name bedrock-asset-processor --query 'Configuration.FunctionName'

echo "=== Tagging ==="
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=barakat-2025-capstone \
    --query 'ResourceTagMappingList[*].ResourceARN' \
    --output text
```
