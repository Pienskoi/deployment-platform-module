provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.2"

  project_id = var.project_id

  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage-api.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "dns.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
}

module "deployment_platform" {
  source = "../../terraform"

  project_id        = var.project_id
  region            = var.region
  zone              = var.zone

  depends_on = [module.project_services]
}