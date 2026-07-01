output "namespace" {
  description = "Namespace where Jenkins is installed"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

output "release_name" {
  description = "Name of the Jenkins Helm release"
  value       = helm_release.jenkins.name
}

output "admin_user" {
  description = "Jenkins admin username"
  value       = var.admin_user
}

output "service_name" {
  description = "Kubernetes Service name of the Jenkins controller"
  value       = helm_release.jenkins.name
}

output "get_admin_password_command" {
  description = "kubectl command to read the generated Jenkins admin password"
  value       = "kubectl exec --namespace ${var.namespace} -it svc/${var.release_name} -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo"
}

output "get_url_command" {
  description = "kubectl command to read the Jenkins LoadBalancer URL"
  value       = "kubectl get svc --namespace ${var.namespace} ${var.release_name} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}
