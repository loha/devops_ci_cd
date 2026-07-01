resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# 1) Install Argo CD itself from the official Helm chart.
resource "helm_release" "argocd" {
  name       = var.release_name
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  values = [
    templatefile("${path.module}/values.yaml", {
      service_type = var.service_type
    })
  ]

  timeout = 900

  depends_on = [kubernetes_namespace.argocd]
}

# 2) Install the local "app-of-apps" chart that registers the Application and
#    Repository objects Argo CD will reconcile. Argo CD then watches the Git
#    repo and auto-syncs the Django Helm chart into the cluster.
resource "helm_release" "app_of_apps" {
  name      = "${var.app_name}-bootstrap"
  namespace = kubernetes_namespace.argocd.metadata[0].name
  chart     = "${path.module}/charts"

  set {
    name  = "application.name"
    value = var.app_name
  }

  set {
    name  = "application.namespace"
    value = var.namespace
  }

  set {
    name  = "application.destinationNamespace"
    value = var.destination_namespace
  }

  set {
    name  = "repository.url"
    value = var.git_repo_url
  }

  set {
    name  = "application.targetRevision"
    value = var.git_target_revision
  }

  set {
    name  = "application.path"
    value = var.chart_path
  }

  set {
    name  = "application.imageRepository"
    value = var.image_repository
  }

  depends_on = [helm_release.argocd]
}
