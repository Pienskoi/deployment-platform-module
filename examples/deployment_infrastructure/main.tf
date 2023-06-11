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

module "deployment_infrastructure" {
  source  = "Pienskoi/deployment-platform/google//modules/deployment_infrastructure"
  version = "0.1.1"

  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}