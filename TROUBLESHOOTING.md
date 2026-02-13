# Troubleshooting Guide - Project Bedrock

## Table of Contents
1. [Terraform Issues](#terraform-issues)
2. [EKS Cluster Issues](#eks-cluster-issues)
3. [Application Issues](#application-issues)
4. [Lambda & S3 Issues](#lambda--s3-issues)
5. [CloudWatch Issues](#cloudwatch-issues)
6. [IAM & Access Issues](#iam--access-issues)
7. [CI/CD Issues](#cicd-issues)

## Terraform Issues

### Issue: Backend doesn't exist

**Symptoms:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:**
```bash
# Run the backend setup script
./setup-backend.sh

# Re-initialize Terraform
cd terraform
terraform init -reconfigure
```

### Issue: State is locked

**Symptoms:**
```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# View the lock
aws dynamodb get-item \
    --table-name project-bedrock-terraform-locks \
    --key '{"LockID":{"S":"project-bedrock-terraform-state/terraform.tfstate"}}'

# If safe to proceed, force unlock
cd terraform
terraform force-unlock <LOCK_ID>
```

### Issue: Module download fails

**Symptoms:**
```
Error: Failed to download module
```

**Solution:**
```bash
# Clear module cache
rm -rf .terraform/modules

# Re-initialize
terraform init -upgrade
```

### Issue: Resource already exists

**Symptoms:**
```
Error: resource already exists
```

**Solution:**
```bash
# Import existing resource
terraform import <resource_type>.<name> <resource_id>

# Or destroy and recreate
terraform destroy -target=<resource>
terraform apply
```

### Issue: Invalid credentials

**Symptoms:**
```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

**Solution:**
```bash
# Check credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

## EKS Cluster Issues

### Issue: Cannot connect to cluster

**Symptoms:**
```
error: You must be logged in to the server (Unauthorized)
```

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig \
    --region us-east-1 \
    --name project-bedrock-cluster

# Verify cluster exists
aws eks describe-cluster \
    --name project-bedrock-cluster \
    --region us-east-1

# Check your IAM identity
aws sts get-caller-identity

# Verify you have permissions
aws eks list-clusters --region us-east-1
```

### Issue: Nodes not joining cluster

**Symptoms:**
```
$ kubectl get nodes
No resources found
```

**Solution:**
```bash
# Check node group status
aws eks describe-nodegroup \
    --cluster-name project-bedrock-cluster \
    --nodegroup-name main \
    --region us-east-1

# Check EC2 instances
aws ec2 describe-instances \
    --filters "Name=tag:eks:cluster-name,Values=project-bedrock-cluster" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
    --output table

# Check instance logs
aws ec2 get-console-output --instance-id <instance-id>

# Common fixes:
# 1. Check security groups allow traffic
# 2. Verify IAM role has correct policies
# 3. Check VPC has correct tags
# 4. Ensure subnets have available IPs
```

### Issue: Cluster creation failed

**Symptoms:**
```
Error: error creating EKS Cluster: timeout while waiting for state
```

**Solution:**
```bash
# Check CloudFormation stacks for errors
aws cloudformation describe-stacks \
    --region us-east-1 \
    | grep -A 5 "StackStatus.*FAILED"

# Check EKS cluster logs
aws eks describe-cluster \
    --name project-bedrock-cluster \
    --query 'cluster.resourcesVpcConfig'

# Common issues:
# - Insufficient IAM permissions
# - Subnet in wrong AZ
# - CIDR conflicts
# - Service quota exceeded
```

### Issue: Pods can't pull images

**Symptoms:**
```
Failed to pull image: Pull rate limit exceeded
```

**Solution:**
```bash
# Check node IAM role has ECR permissions
aws iam get-role \
    --role-name <node-role-name> \
    | grep AmazonEC2ContainerRegistryReadOnly

# Verify image exists and is accessible
aws ecr describe-images --repository-name <repo-name>

# For public images, may hit rate limits
# Solution: Use ECR pull through cache or wait
```

## Application Issues

### Issue: Pods stuck in Pending

**Symptoms:**
```
NAME   READY   STATUS    RESTARTS   AGE
ui-x   0/1     Pending   0          5m
```

**Solution:**
```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n retail-app

# Common causes:
# 1. Insufficient resources
kubectl top nodes
kubectl describe nodes

# 2. No nodes available
kubectl get nodes

# 3. Volume provisioning issues
kubectl get pvc -n retail-app
kubectl describe pvc <pvc-name> -n retail-app

# 4. Image pull issues
kubectl get events -n retail-app --sort-by='.lastTimestamp'

# Fix by scaling nodes or adjusting resources
```

### Issue: Pods in CrashLoopBackOff

**Symptoms:**
```
NAME   READY   STATUS             RESTARTS   AGE
ui-x   0/1     CrashLoopBackOff   5          10m
```

**Solution:**
```bash
# View logs
kubectl logs <pod-name> -n retail-app
kubectl logs <pod-name> -n retail-app --previous

# Check pod events
kubectl describe pod <pod-name> -n retail-app

# Common causes:
# 1. Application error - fix code
# 2. Missing dependencies - check service connectivity
# 3. Configuration issues - verify ConfigMaps/Secrets
# 4. Liveness probe failing - adjust probe settings

# Temporarily disable probes for debugging
kubectl edit deployment <name> -n retail-app
# Comment out livenessProbe section
```

### Issue: Service not accessible

**Symptoms:**
```
Connection refused when accessing service
```

**Solution:**
```bash
# Check service exists
kubectl get svc -n retail-app

# Check service endpoints
kubectl get endpoints -n retail-app
kubectl describe svc ui -n retail-app

# Verify pods are ready
kubectl get pods -n retail-app -l app=ui

# Test service from within cluster
kubectl run -it --rm debug \
    --image=curlimages/curl \
    --restart=Never \
    -n retail-app \
    -- curl http://ui

# Check labels match
kubectl get svc ui -n retail-app -o yaml | grep selector
kubectl get pods -n retail-app --show-labels
```

### Issue: Application slow or unresponsive

**Symptoms:**
```
Application takes long to load or times out
```

**Solution:**
```bash
# Check resource usage
kubectl top pods -n retail-app
kubectl top nodes

# Check for resource limits
kubectl describe pod <pod-name> -n retail-app | grep -A 5 Limits

# Check application logs for errors
kubectl logs <pod-name> -n retail-app | grep -i error

# Check database connectivity
kubectl exec -it <pod-name> -n retail-app -- sh
# Inside pod: try connecting to database

# Scale if needed
kubectl scale deployment ui --replicas=3 -n retail-app
```

## Lambda & S3 Issues

### Issue: Lambda not triggering on S3 upload

**Symptoms:**
```
File uploaded but no Lambda execution logs
```

**Solution:**
```bash
# Check S3 event notification configuration
aws s3api get-bucket-notification-configuration \
    --bucket bedrock-assets-<student-id>

# Should show Lambda function ARN
# If not configured, check Terraform applied correctly

# Check Lambda permissions
aws lambda get-policy \
    --function-name bedrock-asset-processor

# Should include S3 invoke permission

# Test Lambda manually
aws lambda invoke \
    --function-name bedrock-asset-processor \
    --payload '{"Records":[{"s3":{"bucket":{"name":"test-bucket"},"object":{"key":"test.jpg","size":1024}}}]}' \
    response.json

# Check response
cat response.json

# View logs
aws logs tail /aws/lambda/bedrock-asset-processor --follow
```

### Issue: Lambda function errors

**Symptoms:**
```
Lambda execution fails or returns errors
```

**Solution:**
```bash
# View detailed logs
aws logs tail /aws/lambda/bedrock-asset-processor --follow

# Check function configuration
aws lambda get-function-configuration \
    --function-name bedrock-asset-processor

# Update function if needed
cd lambda
zip asset-processor.zip index.py
aws lambda update-function-code \
    --function-name bedrock-asset-processor \
    --zip-file fileb://asset-processor.zip

# Check IAM permissions
aws iam get-role-policy \
    --role-name bedrock-lambda-exec-role \
    --policy-name lambda-s3-read-policy
```

### Issue: Cannot upload to S3 bucket

**Symptoms:**
```
Access Denied when uploading files
```

**Solution:**
```bash
# Check bucket exists
aws s3 ls | grep bedrock-assets

# Check bucket policy/permissions
aws s3api get-bucket-policy \
    --bucket bedrock-assets-<student-id>

# Check your IAM permissions
aws iam list-user-policies --user-name bedrock-dev-view
aws iam get-user-policy \
    --user-name bedrock-dev-view \
    --policy-name bedrock-dev-s3-put-policy

# Try with full AWS access (admin) to isolate issue
# If works, it's a permission issue
```

## CloudWatch Issues

### Issue: No logs appearing

**Symptoms:**
```
CloudWatch log groups empty or not receiving logs
```

**Solution:**
```bash
# Check log groups exist
aws logs describe-log-groups --region us-east-1

# For control plane logs:
# 1. Verify logging enabled
aws eks describe-cluster \
    --name project-bedrock-cluster \
    --query 'cluster.logging'

# 2. Enable if needed
aws eks update-cluster-config \
    --name project-bedrock-cluster \
    --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'

# For application logs:
# 1. Check CloudWatch add-on
aws eks describe-addon \
    --cluster-name project-bedrock-cluster \
    --addon-name amazon-cloudwatch-observability

# 2. Verify daemonset running
kubectl get daemonset -n amazon-cloudwatch

# 3. Check daemonset logs
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=amazon-cloudwatch-observability

# 4. Reinstall add-on if needed
aws eks delete-addon \
    --cluster-name project-bedrock-cluster \
    --addon-name amazon-cloudwatch-observability
# Wait 2 minutes, then terraform apply again
```

### Issue: Logs delayed or missing

**Symptoms:**
```
Logs take long to appear or some are missing
```

**Solution:**
```bash
# Check CloudWatch agent status
kubectl get pods -n amazon-cloudwatch

# View agent logs
kubectl logs -n amazon-cloudwatch <agent-pod-name>

# Check IAM permissions for nodes
aws iam list-attached-role-policies \
    --role-name <node-role-name> \
    | grep CloudWatch

# Verify log retention settings
aws logs describe-log-groups \
    --log-group-name-prefix /aws/eks/project-bedrock
```

## IAM & Access Issues

### Issue: Developer cannot access cluster

**Symptoms:**
```
Error: You must be logged in to the server (Unauthorized)
```

**Solution:**
```bash
# Check user exists
aws iam get-user --user-name bedrock-dev-view

# Check EKS access entry
aws eks list-access-entries \
    --cluster-name project-bedrock-cluster

aws eks describe-access-entry \
    --cluster-name project-bedrock-cluster \
    --principal-arn arn:aws:iam::<account>:user/bedrock-dev-view

# Verify access policies
aws eks list-associated-access-policies \
    --cluster-name project-bedrock-cluster \
    --principal-arn arn:aws:iam::<account>:user/bedrock-dev-view

# If missing, reapply Terraform
cd terraform
terraform apply -target=module.eks
```

### Issue: Developer has too much access

**Symptoms:**
```
Developer can delete pods (should not be able to)
```

**Solution:**
```bash
# Check current permissions
aws iam list-attached-user-policies --user-name bedrock-dev-view

# Check access policies
aws eks list-associated-access-policies \
    --cluster-name project-bedrock-cluster \
    --principal-arn arn:aws:iam::<account>:user/bedrock-dev-view

# Should only have AmazonEKSViewPolicy
# If has more, update Terraform and reapply

# Test permissions
export AWS_ACCESS_KEY_ID="<dev-key>"
export AWS_SECRET_ACCESS_KEY="<dev-secret>"
kubectl delete pod <pod-name> -n retail-app
# Should fail with Forbidden error
```

### Issue: Access key doesn't work

**Symptoms:**
```
InvalidClientTokenId: The security token included in the request is invalid
```

**Solution:**
```bash
# Verify key exists
aws iam list-access-keys --user-name bedrock-dev-view

# Get new output
cd terraform
terraform output developer_access_key_id
terraform output -raw developer_secret_access_key

# If needed, rotate key
terraform taint aws_iam_access_key.bedrock_dev_key
terraform apply
```

## CI/CD Issues

### Issue: GitHub Actions workflow not running

**Symptoms:**
```
No workflows triggered on PR or push
```

**Solution:**
```bash
# Check workflow file exists
ls -la .github/workflows/

# Check workflow is valid YAML
cat .github/workflows/terraform.yml | yq .

# Verify triggers in workflow
grep -A 5 "^on:" .github/workflows/terraform.yml

# Check repository permissions
# Go to: Settings → Actions → General
# Ensure workflows are enabled

# Force trigger manually
gh workflow run terraform.yml
```

### Issue: Workflow fails with AWS credentials error

**Symptoms:**
```
Error: No credentials provided
```

**Solution:**
```bash
# Check secrets are configured
# Go to: Settings → Secrets → Actions

# Verify secrets:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY

# Test credentials locally
export AWS_ACCESS_KEY_ID="<from-secrets>"
export AWS_SECRET_ACCESS_KEY="<from-secrets>"
aws sts get-caller-identity

# Update secrets if needed
```

### Issue: Terraform plan/apply fails in workflow

**Symptoms:**
```
Error: Backend initialization required
```

**Solution:**
```bash
# Ensure backend exists
./setup-backend.sh

# Check workflow has terraform init step
grep "terraform init" .github/workflows/terraform.yml

# Verify backend configuration in main.tf
grep -A 5 "backend" terraform/main.tf

# Check S3 bucket is accessible
aws s3 ls s3://project-bedrock-terraform-state/
```

## General Debugging Commands

```bash
# Get overview of everything
kubectl get all -A
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Describe all resources in namespace
for resource in deployment service pod; do
    echo "=== $resource ==="
    kubectl get $resource -n retail-app
done

# Get all logs
kubectl logs -n retail-app --all-containers --prefix

# Check DNS resolution
kubectl run -it --rm debug \
    --image=busybox \
    --restart=Never \
    -- nslookup kubernetes.default

# Check internet connectivity
kubectl run -it --rm debug \
    --image=curlimages/curl \
    --restart=Never \
    -- curl -I https://google.com
```

## Getting Help

If issues persist after trying these solutions:

1. **Check AWS Service Health**
   ```bash
   # Visit: https://health.aws.amazon.com/health/status
   ```

2. **Review Documentation**
   - [EKS Troubleshooting Guide](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
   - [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug/)

3. **Collect Debug Info**
   ```bash
   # EKS cluster info
   aws eks describe-cluster --name project-bedrock-cluster > cluster-info.json
   
   # All Kubernetes resources
   kubectl get all -A -o yaml > k8s-resources.yaml
   
   # Recent events
   kubectl get events -A --sort-by='.lastTimestamp' > events.log
   
   # Node information
   kubectl describe nodes > nodes-info.txt
   ```

4. **Contact Support**
   - AWS Support (if you have a support plan)
   - Stack Overflow with tag `amazon-eks`
   - GitHub Issues for specific tools

Remember: Always check CloudWatch logs first - they usually contain the root cause!
