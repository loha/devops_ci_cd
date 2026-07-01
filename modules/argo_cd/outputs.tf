output "namespace" {
  description = "Namespace where Argo CD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "release_name" {
  description = "Name of the Argo CD Helm release"
  value       = helm_release.argocd.name
}

output "application_name" {
  description = "Name of the Argo CD Application tracking the Helm chart"
  value       = var.app_name
}

output "get_admin_password_command" {
  description = "kubectl command to read the initial Argo CD admin password"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}

output "get_url_command" {
  description = "kubectl command to read the Argo CD server LoadBalancer URL"
  value       = "kubectl -n ${var.namespace} get svc ${var.release_name}-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}
