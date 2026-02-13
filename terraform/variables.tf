variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "assets_bucket_name" {
  description = "Name of S3 bucket for assets (must be globally unique)"
  type        = string
  # Replace 'your-student-id' with your actual student ID
  default     = "bedrock-assets-1225"
}

variable "student_id" {
  description = "Your student ID for resource naming"
  type        = string
  default     = "1225"
}
