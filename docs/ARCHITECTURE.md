# Project Bedrock Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    project-bedrock-vpc (10.0.0.0/16)           │  │
│  │                                                                 │  │
│  │  ┌──────────────────┐         ┌──────────────────┐            │  │
│  │  │   AZ-1 (us-e-1a) │         │   AZ-2 (us-e-1b) │            │  │
│  │  │                  │         │                  │            │  │
│  │  │  Public Subnet   │         │  Public Subnet   │            │  │
│  │  │  10.0.101.0/24   │         │  10.0.102.0/24   │            │  │
│  │  │  ┌────────────┐  │         │  ┌────────────┐  │            │  │
│  │  │  │ NAT Gateway│  │         │  │            │  │            │  │
│  │  │  └────────────┘  │         │  └────────────┘  │            │  │
│  │  │        │         │         │                  │            │  │
│  │  │  ──────┼─────────┼─────────┼──────────────────┼─────       │  │
│  │  │        │         │         │                  │            │  │
│  │  │  Private Subnet  │         │  Private Subnet  │            │  │
│  │  │  10.0.1.0/24     │         │  10.0.2.0/24     │            │  │
│  │  │  ┌────────────┐  │         │  ┌────────────┐  │            │  │
│  │  │  │ EKS Worker │  │         │  │ EKS Worker │  │            │  │
│  │  │  │   Node 1   │  │         │  │   Node 2   │  │            │  │
│  │  │  │ (t3.medium)│  │         │  │ (t3.medium)│  │            │  │
│  │  │  └────────────┘  │         │  └────────────┘  │            │  │
│  │  │                  │         │                  │            │  │
│  │  └──────────────────┘         └──────────────────┘            │  │
│  │                                                                 │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │        EKS Control Plane (project-bedrock-cluster)             │  │
│  │                    Kubernetes 1.31                             │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                              │                                        │
│                              │                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │              Application Layer (retail-app namespace)          │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │  │
│  │  │    UI    │  │ Catalog  │  │   Cart   │  │  Orders  │      │  │
│  │  │ Service  │  │ Service  │  │ Service  │  │ Service  │      │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │  │
│  │  ┌──────────┐  ┌──────────┐                                   │  │
│  │  │ Checkout │  │  Assets  │                                   │  │
│  │  │ Service  │  │ Service  │                                   │  │
│  │  └──────────┘  └──────────┘                                   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                              │                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │           Data Layer (In-Cluster - Core Requirement)           │  │
│  │  ┌──────────┐  ┌────────────┐  ┌─────────┐  ┌──────────┐     │  │
│  │  │  MySQL   │  │ PostgreSQL │  │  Redis  │  │ RabbitMQ │     │  │
│  │  │(Catalog) │  │  (Orders)  │  │ (Cache) │  │  (Queue) │     │  │
│  │  └──────────┘  └────────────┘  └─────────┘  └──────────┘     │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                    Observability Layer                         │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │              Amazon CloudWatch                            │ │  │
│  │  │  • Control Plane Logs (API, Audit, Auth, Controller)     │ │  │
│  │  │  • Application Logs (Container Insights)                 │ │  │
│  │  │  • Lambda Logs                                            │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │              Event-Driven Extension                            │  │
│  │  ┌──────────────────────┐     ┌────────────────────────────┐  │  │
│  │  │   S3 Bucket          │────▶│  Lambda Function           │  │  │
│  │  │  bedrock-assets-*    │     │  bedrock-asset-processor   │  │  │
│  │  │                      │     │                            │  │  │
│  │  │  [Upload triggers]   │     │  [Logs to CloudWatch]      │  │  │
│  │  └──────────────────────┘     └────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                      IAM & Security                            │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │  Developer User: bedrock-dev-view                        │ │  │
│  │  │  • AWS Console: ReadOnlyAccess                           │ │  │
│  │  │  • Kubernetes: View (via EKS access entries)             │ │  │
│  │  │  • S3: PutObject permission for assets bucket            │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│                          CI/CD Pipeline                                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      GitHub Actions                              │  │
│  │                                                                  │  │
│  │  Pull Request ──▶ terraform plan ──▶ Comment on PR             │  │
│  │                                                                  │  │
│  │  Merge to Main ──▶ terraform apply ──▶ Deploy Infrastructure   │  │
│  │                                      ──▶ Generate grading.json  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Network Layer
- **VPC**: 10.0.0.0/16 CIDR
- **Public Subnets**: 2 subnets for NAT Gateway and future ALB
- **Private Subnets**: 2 subnets for EKS worker nodes
- **Availability Zones**: us-east-1a, us-east-1b
- **Internet Gateway**: Public internet access
- **NAT Gateway**: Private subnet outbound access

### 2. Compute Layer
- **EKS Control Plane**: Fully managed Kubernetes control plane
- **Worker Nodes**: 2x t3.medium instances in auto-scaling group
- **Managed Node Group**: AWS-managed node lifecycle

### 3. Application Layer (retail-app namespace)
- **UI Service**: React frontend (2 replicas)
- **Catalog Service**: Product catalog management (2 replicas)
- **Cart Service**: Shopping cart functionality (2 replicas)
- **Orders Service**: Order processing (2 replicas)
- **Checkout Service**: Payment processing (2 replicas)
- **Assets Service**: Static asset serving (2 replicas)

### 4. Data Layer (In-Cluster)
- **MySQL**: Catalog database (1 pod with persistent storage)
- **PostgreSQL**: Orders database (1 pod with persistent storage)
- **Redis**: Session and cart caching (1 pod with persistent storage)
- **RabbitMQ**: Asynchronous messaging (1 pod with persistent storage)

### 5. Observability
- **EKS Control Plane Logs**: All 5 log types to CloudWatch
- **CloudWatch Observability Add-on**: Container logs collection
- **Lambda Logs**: Asset processor execution logs

### 6. Event-Driven Architecture
- **S3 Bucket**: Asset storage with versioning
- **Lambda Function**: Python-based asset processor
- **S3 Event Notification**: Triggers Lambda on object creation

### 7. Security & Access
- **IAM Roles**: EKS cluster role, node group role, Lambda execution role
- **Developer User**: Read-only access to AWS and Kubernetes
- **RBAC**: Kubernetes view permissions via EKS access entries
- **Security Groups**: Restricted network access

### 8. Infrastructure as Code
- **Terraform**: All infrastructure defined as code
- **Remote State**: S3 backend with DynamoDB locking
- **Modules**: VPC and EKS modules from Terraform Registry

## Data Flow

### Application Request Flow
```
User ──▶ Port Forward ──▶ UI Service ──▶ Catalog/Cart/Orders ──▶ Databases
                                     └──▶ Assets Service ──▶ Static Files
```

### Asset Processing Flow
```
User ──▶ Upload File ──▶ S3 Bucket ──▶ Event Notification ──▶ Lambda ──▶ CloudWatch Logs
```

### Logging Flow
```
EKS Control Plane ──▶ CloudWatch Log Groups
Container Logs ──────▶ CloudWatch Observability Add-on ──▶ CloudWatch
Lambda Execution ─────▶ CloudWatch Logs
```

### Developer Access Flow
```
Developer ──▶ IAM Credentials ──▶ AWS Console (Read-Only)
                              └──▶ kubectl via EKS ──▶ View Pods/Services
                              └──▶ S3 Upload (PutObject)
```

## Deployment Flow

```
1. Setup Backend
   ├─▶ Create S3 bucket for state
   └─▶ Create DynamoDB table for locks

2. Deploy Infrastructure (Terraform)
   ├─▶ VPC with subnets
   ├─▶ EKS cluster
   ├─▶ IAM roles and users
   ├─▶ S3 bucket for assets
   └─▶ Lambda function

3. Deploy Application (Helm)
   ├─▶ Create namespace
   ├─▶ Install retail store chart
   └─▶ Wait for pods ready

4. Verify
   ├─▶ Check pods status
   ├─▶ Test application access
   ├─▶ Verify logs in CloudWatch
   └─▶ Test S3/Lambda pipeline
```

## Scaling Considerations

### Horizontal Scaling
- **Node Group**: Can scale from 2 to 4 nodes
- **Application Pods**: Can increase replica count
- **Cluster Autoscaler**: Can be added for automatic scaling

### Vertical Scaling
- **Instance Types**: Can upgrade from t3.medium
- **Pod Resources**: Adjust CPU/memory limits
- **Database**: Can migrate to RDS (bonus objective)

## Security Considerations

### Network Security
- Private subnets for worker nodes
- Security groups restrict traffic
- NAT Gateway for outbound only

### Access Control
- IAM roles follow least privilege
- Developer access is read-only
- No credentials in code

### Data Security
- S3 bucket encryption enabled
- EBS volumes encrypted
- Secrets management via Kubernetes

## Monitoring & Alerting

### Available Metrics
- EKS cluster health
- Node resource utilization
- Pod status and restarts
- Application logs
- Lambda invocations

### CloudWatch Integration
- Control plane logs
- Container logs
- Custom application metrics
- Lambda execution logs

## Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| EKS Cluster | 1 cluster | $73 |
| EC2 Instances | 2x t3.medium | $60 |
| NAT Gateway | 1 gateway | $33 |
| EBS Volumes | 40 GB | $4 |
| CloudWatch Logs | ~5 GB | $5 |
| S3 + Lambda | Minimal usage | $1 |
| **Total** | | **~$175/month** |

## Bonus Architecture (Optional)

### Managed Persistence
```
Replace in-cluster databases with:
├─▶ Amazon RDS MySQL (Catalog)
├─▶ Amazon RDS PostgreSQL (Orders)
├─▶ Amazon ElastiCache Redis (Cache)
└─▶ Amazon MQ (RabbitMQ)
```

### Public Access
```
Add:
├─▶ AWS Load Balancer Controller
├─▶ Ingress resource
├─▶ Application Load Balancer
├─▶ Route 53 DNS
└─▶ ACM Certificate (TLS)
```

## References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Retail Store Sample App](https://github.com/aws/retail-store-sample-app)
- [Terraform AWS Modules](https://registry.terraform.io/modules/terraform-aws-modules/)
