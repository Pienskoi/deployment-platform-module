module "dns_private_zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "private"
  name       = "project-com"
  domain     = "project.com."

  private_visibility_config_networks = [module.vpc.network_self_link]
}

module "private_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id       = var.project_id
  region           = var.region
  subnetwork       = module.subnets.subnets["${var.region}/project-subnet"].name
  enable_cloud_dns = true
  dns_domain       = "project.com"
  dns_managed_zone = module.dns_private_zone.name
  dns_project      = var.project_id

  names = [
    "docker-registry-static-ip",
    "jenkins-static-ip",
    "internal-spring-petclinic-ip"
  ]

  dns_short_names = [
    "docker-registry",
    "jenkins",
    "qa"
  ]
}

module "regional_public_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id   = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  names        = ["wireguard-static-ip"]
}

module "global_public_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id   = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  global       = true

  names = [
    "spring-petclinic-static-ip",
    "jenkins-webhook-static-ip"
  ]
}

module "dns_public_zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "public"
  name       = "spring-petclinic-tk"
  domain     = "${var.domain}."

  private_visibility_config_networks = [module.vpc.network_self_link]

  recordsets = [{
    name    = ""
    type    = "A"
    ttl     = 300
    records = [module.global_public_address.addresses[0]]
  }]
}
