module "dns_private_zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "private"
  name       = "private-zone"
  domain     = "project.com."

  private_visibility_config_networks = [data.google_compute_network.network.self_link]
}

module "private_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id       = var.project_id
  region           = var.region
  subnetwork       = var.subnet_name
  enable_cloud_dns = true
  dns_domain       = "project.com"
  dns_managed_zone = module.dns_private_zone.name
  dns_project      = var.project_id

  names = [
    "jenkins-static-ip",
    "app-private-ip"
  ]

  dns_short_names = [
    "jenkins",
    "dev"
  ]
}

module "global_public_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id   = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  global       = true

  names = [
    "app-public-ip",
    "jenkins-webhook-static-ip"
  ]
}

module "dns_public_zone" {
  count = var.domain == "" ? 0 : 1

  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "public"
  name       = "public-zone"
  domain     = "${var.domain}."

  private_visibility_config_networks = [data.google_compute_network.network.self_link]

  recordsets = [{
    name    = ""
    type    = "A"
    ttl     = 300
    records = [module.global_public_address.addresses[0]]
  }]
}
