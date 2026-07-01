variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "git_repo_url" {
  description = "Git repository URL that hosts the Helm chart Argo CD tracks"
  type        = string
  default     = "https://github.com/loha/devops_ci_cd.git"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password. Leave empty to let the chart generate one."
  type        = string
  default     = ""
  sensitive   = true
}
