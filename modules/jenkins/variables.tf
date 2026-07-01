variable "namespace" {
  description = "Kubernetes namespace where Jenkins will be installed"
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = "Version of the Jenkins Helm chart"
  type        = string
  default     = "5.8.18"
}

variable "release_name" {
  description = "Name of the Jenkins Helm release"
  type        = string
  default     = "jenkins"
}

variable "admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Jenkins admin password. If empty, the chart generates a random one."
  type        = string
  default     = ""
  sensitive   = true
}

variable "service_type" {
  description = "Kubernetes Service type for the Jenkins controller (LoadBalancer/ClusterIP/NodePort)"
  type        = string
  default     = "LoadBalancer"
}

variable "storage_class" {
  description = "StorageClass used for the Jenkins persistent volume (EBS CSI)"
  type        = string
  default     = "gp2"
}

variable "storage_size" {
  description = "Size of the Jenkins persistent volume"
  type        = string
  default     = "8Gi"
}

variable "ecr_registry" {
  description = "ECR registry URL passed to the pipeline (e.g. <acct>.dkr.ecr.us-west-2.amazonaws.com)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region used by the Jenkins agents / pipeline"
  type        = string
  default     = "us-west-2"
}
