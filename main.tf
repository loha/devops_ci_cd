terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Auth token for the EKS cluster, used by the Kubernetes/Helm providers.
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "oleksii-nosov-terraform-state"
  table_name  = "terraform-locks"
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "lesson-7-vpc"
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-7-ecr"
  scan_on_push = true
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = "lesson-7-eks"
  cluster_version    = "1.29"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}

module "jenkins" {
  source         = "./modules/jenkins"
  namespace      = "jenkins"
  service_type   = "LoadBalancer"
  admin_user     = "admin"
  admin_password = var.jenkins_admin_password
  storage_class  = "gp2"
  ecr_registry   = split("/", module.ecr.repository_url)[0]
  aws_region     = var.aws_region

  depends_on = [module.eks]
}

module "argo_cd" {
  source                = "./modules/argo_cd"
  namespace             = "argocd"
  service_type          = "LoadBalancer"
  git_repo_url          = var.git_repo_url
  git_target_revision   = "main"
  chart_path            = "charts/django-app"
  app_name              = "django-app"
  destination_namespace = "default"
  image_repository      = module.ecr.repository_url

  depends_on = [module.eks]
}
