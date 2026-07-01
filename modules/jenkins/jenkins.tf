resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "helm_release" "jenkins" {
  name       = var.release_name
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version

  # Base configuration (Kubernetes agents, plugins, service type, persistence).
  values = [
    templatefile("${path.module}/values.yaml", {
      admin_user    = var.admin_user
      service_type  = var.service_type
      storage_class = var.storage_class
      storage_size  = var.storage_size
      ecr_registry  = var.ecr_registry
      aws_region    = var.aws_region
    })
  ]

  # Admin password: use the provided one, otherwise let the chart generate it.
  dynamic "set_sensitive" {
    for_each = var.admin_password == "" ? [] : [var.admin_password]
    content {
      name  = "controller.admin.password"
      value = set_sensitive.value
    }
  }

  timeout = 900

  depends_on = [kubernetes_namespace.jenkins]
}
