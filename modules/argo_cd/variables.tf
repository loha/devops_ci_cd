variable "namespace" {
  description = "Kubernetes namespace where Argo CD will be installed"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the Argo CD Helm chart"
  type        = string
  default     = "7.7.11"
}

variable "release_name" {
  description = "Name of the Argo CD Helm release"
  type        = string
  default     = "argocd"
}

variable "service_type" {
  description = "Kubernetes Service type for the Argo CD server (LoadBalancer/ClusterIP/NodePort)"
  type        = string
  default     = "LoadBalancer"
}

variable "git_repo_url" {
  description = "Git repository URL that hosts the Helm chart Argo CD should track"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/revision Argo CD should follow"
  type        = string
  default     = "main"
}

variable "chart_path" {
  description = "Path to the Helm chart inside the Git repository"
  type        = string
  default     = "charts/django-app"
}

variable "app_name" {
  description = "Name of the Argo CD Application"
  type        = string
  default     = "django-app"
}

variable "destination_namespace" {
  description = "Namespace inside the cluster where the tracked application is deployed"
  type        = string
  default     = "default"
}

variable "image_repository" {
  description = "ECR image repository passed to the tracked chart"
  type        = string
  default     = ""
}
