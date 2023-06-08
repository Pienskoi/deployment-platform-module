module "jenkins_workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 25.0"

  name       = "jenkins-agent"
  namespace  = kubernetes_namespace.namespaces["jenkins"].metadata[0].name
  project_id = var.project_id

  roles = ["roles/container.developer"]
}

module "prod_service_workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 25.0"

  for_each = toset(local.service_names)

  name       = each.value
  namespace  = kubernetes_namespace.namespaces["production"].metadata[0].name
  project_id = var.project_id

  roles = ["roles/cloudsql.client"]
}

module "dev_service_workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 25.0"

  for_each = toset(local.service_names)

  name        = each.value
  gcp_sa_name = "dev-${each.value}"
  namespace   = kubernetes_namespace.namespaces["development"].metadata[0].name
  project_id  = var.project_id

  roles = ["roles/cloudsql.client"]
}
