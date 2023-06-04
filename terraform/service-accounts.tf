module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.1"

  project_id    = var.project_id
  generate_keys = true

  names = [
    "jenkins",
    "wireguard"
  ]

  descriptions = [
    "Service account used by Jenkins agents",
    "Service account used by WireGuard server"
  ]
}

resource "google_project_iam_member" "jenkins_gke_iam_member" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["jenkins"].email}"
}
