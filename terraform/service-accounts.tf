module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.1"

  project_id    = var.project_id
  generate_keys = true

  names = [
    "ansible-control-node",
    "docker-registry-storage",
    "gke-deploy",
    "os-login"
  ]

  descriptions = [
    "Service account used to create Ansible dynamic inventory",
    "Service account used by Docker registry to access GCS",
    "Service account used to deploy application to GKE clusters",
    "Service account used to connect to instances by SSH"
  ]
}

resource "google_service_account" "ansible_managed_node_sa" {
  account_id  = "ansible-managed-node"
  description = "Service account used by Ansible managed nodes"
}

resource "google_service_account_iam_member" "ansible_managed_node_sa_iam" {
  service_account_id = google_service_account.ansible_managed_node_sa.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.service_accounts.service_accounts_map["os-login"].email}"
}

resource "google_service_account" "wireguard_sa" {
  account_id  = "wireguard"
  description = "Service account used by WireGuard server"
}

resource "google_service_account_iam_member" "wireguard_sa_iam" {
  service_account_id = google_service_account.wireguard_sa.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.service_accounts.service_accounts_map["os-login"].email}"
}

resource "google_project_iam_member" "ansible_control_node_sa_iam" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["ansible-control-node"].email}"
}

resource "google_project_iam_member" "os_login_sa_iam" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["os-login"].email}"
}

resource "google_project_iam_member" "gke_deploy_sa_iam" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["gke-deploy"].email}"
}
