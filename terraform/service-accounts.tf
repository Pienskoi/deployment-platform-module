module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.1"

  project_id    = var.project_id
  generate_keys = true

  names = [
    "docker-registry-storage",
    "gke-deploy"
  ]

  descriptions = [
    "Service account used by Docker registry to access GCS",
    "Service account used to deploy application to GKE clusters"
  ]
}

resource "google_service_account" "wireguard_sa" {
  account_id  = "wireguard"
  description = "Service account used by WireGuard server"
}

resource "google_project_iam_member" "gke_deploy_sa_iam" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["gke-deploy"].email}"
}
