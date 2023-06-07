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
  source = "../../terraform"

  project_id        = var.project_id
  region            = var.region
  zone              = var.zone

  depends_on = [module.project_services]
}