module "jenkins_workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 25.0"

  name       = jenkins
  namespace  = kubernetes_namespace.namespaces["jenkins"].name
  project_id = var.project_id

  roles = ["roles/container.developer"]
}

module "prod_service_workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 25.0"

  for_each = toset(local.service_names)

  name        = each.value
  gcp_sa_name = var.jenkins_sa_name
  namespace   = kubernetes_namespace.namespaces["production"].name
  project_id  = var.project_id

  roles = ["roles/cloudsql.client"]
}

module "dev_service_workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 25.0"

  for_each = toset(local.service_names)

  name       = each.value
  namespace  = kubernetes_namespace.namespaces["development"].name
  project_id = var.project_id

  roles = ["roles/cloudsql.client"]
}
