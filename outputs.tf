output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = module.s3_backend.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3_backend.bucket_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = module.s3_backend.dynamodb_table_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

# ---------------------------------------------------------------------------
# Jenkins
# ---------------------------------------------------------------------------
output "jenkins_namespace" {
  description = "Namespace where Jenkins is installed"
  value       = module.jenkins.namespace
}

output "jenkins_url_command" {
  description = "Command to fetch the Jenkins LoadBalancer URL"
  value       = module.jenkins.get_url_command
}

output "jenkins_admin_password_command" {
  description = "Command to fetch the Jenkins admin password"
  value       = module.jenkins.get_admin_password_command
}

# ---------------------------------------------------------------------------
# Argo CD
# ---------------------------------------------------------------------------
output "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  value       = module.argo_cd.namespace
}

output "argocd_application_name" {
  description = "Name of the Argo CD Application"
  value       = module.argo_cd.application_name
}

output "argocd_url_command" {
  description = "Command to fetch the Argo CD server LoadBalancer URL"
  value       = module.argo_cd.get_url_command
}

output "argocd_admin_password_command" {
  description = "Command to fetch the initial Argo CD admin password"
  value       = module.argo_cd.get_admin_password_command
}
