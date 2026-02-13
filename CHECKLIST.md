# Project Bedrock Submission Checklist

## Pre-Submission Verification

### 1. Infrastructure Standards ✓
- [ ] All resources deployed in `us-east-1`
- [ ] EKS cluster named exactly: `project-bedrock-cluster`
- [ ] VPC tagged with name: `project-bedrock-vpc`
- [ ] Application namespace is exactly: `retail-app`
- [ ] IAM user named exactly: `bedrock-dev-view`
- [ ] S3 bucket follows pattern: `bedrock-assets-[your-student-id]`
- [ ] Lambda function named exactly: `bedrock-asset-processor`
- [ ] All resources tagged: `Project: barakat-2025-capstone`

### 2. Infrastructure Validation
- [ ] VPC has 2 public and 2 private subnets across 2 AZs
- [ ] EKS cluster version >= 1.31
- [ ] Managed node group with 2+ nodes running
- [ ] Remote state configured in S3 with DynamoDB locking
- [ ] All Terraform configurations in IaC (no manual resources)

### 3. Application Deployment
- [ ] All retail-app pods are `Running`
- [ ] All pods show `READY 1/1` or appropriate count
- [ ] Services are accessible within cluster
- [ ] Can access UI via port-forward: `kubectl port-forward -n retail-app svc/ui 8080:80`
- [ ] Application loads in browser at `http://localhost:8080`

### 4. Security & Access
- [ ] Developer IAM user has `ReadOnlyAccess` policy attached
- [ ] Developer user has EKS cluster access via access entry
- [ ] Developer user has PutObject permission for S3 bucket
- [ ] Verified: `kubectl get pods -n retail-app` works with dev credentials
- [ ] Verified: `kubectl delete pod` fails with dev credentials
- [ ] Access Key ID and Secret Key documented for grading

### 5. Observability
- [ ] EKS control plane logging enabled (all 5 types)
- [ ] CloudWatch Observability add-on installed
- [ ] Can see control plane logs in CloudWatch
- [ ] Can see application logs in CloudWatch
- [ ] Logs persist and are searchable

### 6. Serverless Extension
- [ ] S3 bucket created and configured
- [ ] Lambda function deployed successfully
- [ ] S3 event notification configured
- [ ] Test file upload triggers Lambda
- [ ] Lambda logs "Image received: [filename]" to CloudWatch
- [ ] Developer user can upload files to S3 bucket

### 7. CI/CD Pipeline
- [ ] GitHub Actions workflow file exists: `.github/workflows/terraform.yml`
- [ ] AWS credentials stored as GitHub secrets
- [ ] `terraform plan` runs on Pull Request
- [ ] Plan output comments on PR
- [ ] `terraform apply` runs on merge to main
- [ ] `grading.json` generated and uploaded as artifact

### 8. Documentation & Deliverables
- [ ] Repository is public or access granted
- [ ] README.md is comprehensive
- [ ] DEPLOYMENT.md has detailed instructions
- [ ] Architecture diagram included
- [ ] All code properly commented
- [ ] `grading.json` committed to repository root

### 9. Required Outputs
Run and verify all outputs are present:
```bash
cd terraform
terraform output -json > grading.json
```

Required outputs in grading.json:
- [ ] cluster_endpoint
- [ ] cluster_name
- [ ] region
- [ ] vpc_id
- [ ] assets_bucket_name

### 10. Grading Credentials
Document for submission:
- [ ] Developer Access Key ID: `__________________`
- [ ] Developer Secret Access Key: `__________________`
- [ ] S3 Bucket Name: `__________________`
- [ ] Application URL method: Port-forward instructions

### 11. Google Doc Submission

Create Google Document with:
- [ ] Document title: "Project Bedrock - [Your Name]"
- [ ] Git Repository Link (public or access granted)
- [ ] Architecture Diagram (embedded or linked)
- [ ] Deployment Guide (URL to application)
- [ ] Developer Credentials (Access Key ID & Secret)
- [ ] Screenshots of:
  - [ ] Running pods: `kubectl get pods -n retail-app`
  - [ ] CloudWatch logs
  - [ ] Lambda execution log
  - [ ] Application UI
- [ ] Share with: Innocent Chukwuemeka (Viewer access)

## Final Tests

### Test 1: Clean Deploy
From scratch (in test environment):
```bash
./setup-backend.sh
cd terraform && terraform init && terraform apply -auto-approve
cd .. && ./deploy.sh
```
Expected: All succeeds, app running

### Test 2: Developer Access
```bash
export AWS_ACCESS_KEY_ID="<dev-key-id>"
export AWS_SECRET_ACCESS_KEY="<dev-secret>"
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
kubectl get pods -n retail-app  # Should succeed
kubectl delete pod <name> -n retail-app  # Should fail
```

### Test 3: S3 Lambda Pipeline
```bash
echo "test" > test.jpg
aws s3 cp test.jpg s3://bedrock-assets-[student-id]/
aws logs tail /aws/lambda/bedrock-asset-processor --follow
```
Expected: See "Image received: test.jpg"

### Test 4: CI/CD
```bash
git checkout -b test
echo "test" >> README.md
git commit -am "Test CI/CD"
git push origin test
```
Create PR, verify plan runs and comments

### Test 5: Resource Tagging
```bash
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=barakat-2025-capstone \
    --region us-east-1
```
Expected: All resources listed

## Submission Timeline

- [ ] Day -3: Complete core requirements
- [ ] Day -2: Test everything thoroughly
- [ ] Day -1: Create documentation and diagrams
- [ ] Day 0: Final verification and submission

## Common Mistakes to Avoid

1. ❌ Wrong resource names (check exact spelling)
2. ❌ Wrong AWS region (must be us-east-1)
3. ❌ Missing resource tags
4. ❌ Hardcoded credentials in code
5. ❌ Local terraform state (must be remote)
6. ❌ Missing grading.json file
7. ❌ Incorrect IAM permissions for developer
8. ❌ Application not in retail-app namespace
9. ❌ Lambda not logging correctly
10. ❌ CloudWatch logs not enabled

## Score Optimization

Core Requirements (85%):
- Standards (5%): Perfect naming, tagging, region
- Infrastructure (20%): Clean IaC, working VPC/EKS
- Application (15%): All pods healthy, accessible
- Security (15%): Developer access correctly configured
- Observability (10%): All logs working
- Serverless (10%): S3+Lambda pipeline functional
- CI/CD (10%): Working pipeline with plan/apply

Bonus Points (15%):
- RDS integration instead of in-cluster DBs
- ALB ingress with custom domain
- TLS certificate from ACM

## Post-Submission

After submission:
1. Keep resources running until grading complete
2. Monitor CloudWatch for any issues
3. Check GitHub Actions for successful runs
4. Be available for questions

## Emergency Contacts

If major issues arise:
- Check CloudWatch logs first
- Review pod events: `kubectl describe pod`
- Verify IAM permissions
- Check Terraform state lock

Good luck! 🚀
