module "vpc" {
  source  = "terraform-google-modules/network/google//modules/vpc"
  version = "~> 5.0"

  network_name = var.vpc_name
  project_id   = var.project_id
}

module "subnets" {
  source  = "terraform-google-modules/network/google//modules/subnets-beta"
  version = "~> 5.0"

  project_id   = var.project_id
  network_name = module.vpc.network_name

  subnets = [
    {
      subnet_name   = "project-subnet"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = var.region
    },
    {
      subnet_name   = "proxy-only-subnet"
      subnet_ip     = "10.20.10.0/24"
      subnet_region = var.region
      purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
      role          = "ACTIVE"
    }
  ]

  secondary_ranges = {
    project-subnet = [
      {
        range_name    = "gke-ip-range-pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "gke-ip-range-svc"
        ip_cidr_range = "10.4.0.0/20"
      }
    ]
  }
}

resource "google_compute_firewall" "project_subnet_allow_internal" {
  name          = "project-subnet-allow-internal"
  project       = var.project_id
  network       = module.vpc.network_name
  direction     = "INGRESS"
  source_ranges = [module.subnets.subnets["${var.region}/project-subnet"].ip_cidr_range]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 1.3"

  name    = "project-router"
  project = var.project_id
  region  = var.region
  network = module.vpc.network_self_link

  nats = [{
    name = "project-nat"
  }]
}
