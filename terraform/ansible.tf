module "build_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.7"

  project_id           = var.project_id
  region               = var.region
  subnetwork           = module.subnets.subnets["${var.region}/project-subnet"].name
  source_image_family  = "debian-10"
  source_image_project = "debian-cloud"
  machine_type         = "n1-standard-1"
  tags                 = ["ansible"]

  service_account = {
    email  = google_service_account.ansible_managed_node_sa.email
    scopes = ["cloud-platform"]
  }

  labels = {
    "ansible" = "build"
  }

  metadata = {
    "enable-oslogin" = "true"
  }
}

module "build_compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.7"

  region            = var.region
  zone              = var.zone
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  hostname          = "ansible-build-node"
  instance_template = module.build_instance_template.self_link
}

module "deploy_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.7"

  project_id           = var.project_id
  region               = var.region
  subnetwork           = module.subnets.subnets["${var.region}/project-subnet"].name
  source_image_family  = "debian-10"
  source_image_project = "debian-cloud"
  machine_type         = "n1-standard-1"
  tags                 = ["ansible"]

  service_account = {
    email  = google_service_account.ansible_managed_node_sa.email
    scopes = ["cloud-platform"]
  }

  labels = {
    "ansible" = "deploy"
  }

  metadata = {
    "enable-oslogin" = "true"
  }
}

module "deploy_compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.7"

  region            = var.region
  zone              = var.zone
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  hostname          = "ansible-deploy-node"
  instance_template = module.deploy_instance_template.self_link
}
