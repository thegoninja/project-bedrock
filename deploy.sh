#!/bin/bash

# Project Bedrock Deployment Script
# This script deploys the retail store application to EKS

set -e

echo "=== Project Bedrock Deployment ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed${NC}"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}helm is not installed${NC}"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites installed${NC}"
    echo ""
}

# Configure kubectl for EKS
configure_kubectl() {
    echo "Configuring kubectl for EKS cluster..."
    
    aws eks update-kubeconfig \
        --region us-east-1 \
        --name project-bedrock-cluster
    
    echo -e "${GREEN}✓ kubectl configured${NC}"
    echo ""
}

# Create namespace
create_namespace() {
    echo "Creating retail-app namespace..."
    
    kubectl apply -f k8s/namespace.yaml
    
    echo -e "${GREEN}✓ Namespace created${NC}"
    echo ""
}

# Install retail store app using Helm
install_app() {
    echo "Installing AWS Retail Store Sample App..."
    
    # Add the AWS samples Helm repository
    helm repo add aws-samples https://aws.github.io/retail-store-sample-app/
    helm repo update
    
    # Install the application
    helm upgrade --install retail-store aws-samples/retail-store-sample-app \
        --namespace retail-app \
        --values k8s/values.yaml \
        --wait \
        --timeout 10m
    
    echo -e "${GREEN}✓ Application installed${NC}"
    echo ""
}

# Wait for pods to be ready
wait_for_pods() {
    echo "Waiting for all pods to be ready..."
    
    kubectl wait --for=condition=ready pod \
        --all \
        --namespace retail-app \
        --timeout=600s
    
    echo -e "${GREEN}✓ All pods are ready${NC}"
    echo ""
}

# Display pod status
show_status() {
    echo "=== Deployment Status ==="
    echo ""
    
    echo "Pods in retail-app namespace:"
    kubectl get pods -n retail-app -o wide
    echo ""
    
    echo "Services in retail-app namespace:"
    kubectl get svc -n retail-app
    echo ""
}

# Get UI service endpoint
get_ui_endpoint() {
    echo "=== Application Access ==="
    echo ""
    
    # Port forward to UI service
    echo "To access the application, run:"
    echo -e "${YELLOW}kubectl port-forward -n retail-app svc/ui 8080:80${NC}"
    echo ""
    echo "Then open your browser to: http://localhost:8080"
    echo ""
}

# Main deployment flow
main() {
    check_prerequisites
    configure_kubectl
    create_namespace
    install_app
    wait_for_pods
    show_status
    get_ui_endpoint
    
    echo -e "${GREEN}=== Deployment Complete! ===${NC}"
}

# Run main function
main
