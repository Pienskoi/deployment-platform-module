module "vpc" {
  source  = "terraform-google-modules/network/google//modules/vpc"
  version = "~> 5.0"

  network_name = "project-vpc"
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
        range_name    = "ip-range-pods-infr"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "ip-range-svc-infr"
        ip_cidr_range = "10.4.0.0/20"
      },
      {
        range_name    = "ip-range-pods-ci"
        ip_cidr_range = "10.2.0.0/16"
      },
      {
        range_name    = "ip-range-svc-ci"
        ip_cidr_range = "10.4.16.0/20"
      },
      {
        range_name    = "ip-range-pods-qa"
        ip_cidr_range = "10.3.0.0/16"
      },
      {
        range_name    = "ip-range-svc-qa"
        ip_cidr_range = "10.4.32.0/20"
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

resource "google_compute_firewall" "pods_infr_allow_ssh" {
  name          = "pods-infr-allow-ssh"
  project       = var.project_id
  network       = module.vpc.network_name
  direction     = "INGRESS"
  source_ranges = [module.subnets.subnets["${var.region}/project-subnet"].secondary_ip_range[0].ip_cidr_range]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["ansible"]
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

module "gke_infrastructure" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id        = var.project_id
  name              = var.gke_infrastructure_cluster_name
  region            = var.region
  zones             = [var.zone]
  network           = module.vpc.network_name
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  ip_range_pods     = "ip-range-pods-infr"
  ip_range_services = "ip-range-svc-infr"

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "n2-standard-2"
    image_type   = "COS_CONTAINERD"
    autoscaling  = true
    min_count    = 1
    max_count    = 3
  }]

  master_ipv4_cidr_block = "10.0.0.0/28"
  master_authorized_networks = [
    {
      cidr_block   = module.subnets.subnets["${var.region}/project-subnet"].ip_cidr_range
      display_name = "VPC project-subnet"
    }
  ]
}

module "gke_qa" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id        = var.project_id
  name              = var.gke_qa_cluster_name
  region            = var.region
  zones             = [var.zone]
  network           = module.vpc.network_name
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  ip_range_pods     = "ip-range-pods-qa"
  ip_range_services = "ip-range-svc-qa"

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "n1-standard-1"
    image_type   = "COS_CONTAINERD"
    autoscaling  = true
    min_count    = 1
    max_count    = 10
  }]

  master_ipv4_cidr_block = "10.0.0.16/28"
  master_authorized_networks = [
    {
      cidr_block   = module.subnets.subnets["${var.region}/project-subnet"].ip_cidr_range
      display_name = "VPC project-subnet"
    },
    {
      cidr_block   = module.subnets.subnets["${var.region}/project-subnet"].secondary_ip_range[0].ip_cidr_range
      display_name = "Infrastructure cluster pods"
    }
  ]
}

module "gke_ci" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id        = var.project_id
  name              = var.gke_ci_cluster_name
  region            = var.region
  zones             = [var.zone]
  network           = module.vpc.network_name
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  ip_range_pods     = "ip-range-pods-ci"
  ip_range_services = "ip-range-svc-ci"

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "n1-standard-1"
    image_type   = "COS_CONTAINERD"
    autoscaling  = true
    min_count    = 1
    max_count    = 10
  }]

  master_ipv4_cidr_block = "10.0.0.32/28"
  master_authorized_networks = [
    {
      cidr_block   = module.subnets.subnets["${var.region}/project-subnet"].ip_cidr_range
      display_name = "VPC project-subnet"
    },
    {
      cidr_block   = module.subnets.subnets["${var.region}/project-subnet"].secondary_ip_range[0].ip_cidr_range
      display_name = "Infrastructure cluster pods"
    }
  ]
}

module "workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 20.0"

  project_id          = var.project_id
  name                = "mysql-workload-identity"
  namespace           = "petclinic"
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
  roles               = ["roles/cloudsql.client"]

  depends_on = [module.gke_ci.name]
}

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

resource "random_string" "bucket_name_suffix" {
  length  = 4
  special = false
  upper   = false
}

module "bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 3.2"

  name       = "docker-registry-bucket-${random_string.bucket_name_suffix.result}"
  project_id = var.project_id
  location   = var.region

  force_destroy = true
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = module.bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.service_accounts.service_accounts_map["docker-registry-storage"].email}"
}

module "private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "~> 10.0"

  project_id  = var.project_id
  vpc_network = module.vpc.network_name

  depends_on = [module.vpc]
}

module "safer_mysql_db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/safer_mysql"
  version = "~> 10.0"

  name                 = "project-mysql"
  random_instance_name = true
  project_id           = var.project_id
  database_version     = "MYSQL_5_7"
  region               = var.region
  zone                 = var.zone
  tier                 = "db-n1-standard-1"
  user_name            = var.sql_user_name
  user_password        = var.sql_user_password

  vpc_network        = module.vpc.network_self_link
  allocated_ip_range = module.private_service_access.google_compute_global_address_name
  assign_public_ip   = false

  additional_databases = [{
    name      = var.sql_database_name
    charset   = ""
    collation = ""
  }]

  deletion_protection = false

  module_depends_on = [module.private_service_access.peering_completed]
}

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
  domain     = "spring-petclinic.tk."

  private_visibility_config_networks = [module.vpc.network_self_link]

  recordsets = [{
    name    = ""
    type    = "A"
    ttl     = 300
    records = [module.global_public_address.addresses[0]]
  }]
}

resource "google_dns_policy" "project_dns_policy" {
  name                      = "project-dns-policy"
  enable_inbound_forwarding = true

  networks {
    network_url = module.vpc.network_id
  }
}

module "wireguard_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.7"

  project_id           = var.project_id
  region               = var.region
  subnetwork           = module.subnets.subnets["${var.region}/project-subnet"].name
  source_image_family  = "debian-10"
  source_image_project = "debian-cloud"
  machine_type         = "n1-standard-1"
  can_ip_forward       = true
  tags                 = ["wireguard"]

  startup_script = templatefile("./wireguard_script.sh", {
    interface_address = module.private_address.addresses[2]
  })

  service_account = {
    email  = google_service_account.wireguard_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    "enable-oslogin" = "true"
  }
}

module "wireguard_compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.7"

  region            = var.region
  zone              = var.zone
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  hostname          = "wireguard"
  instance_template = module.wireguard_instance_template.self_link

  access_config = [{
    nat_ip       = module.regional_public_address.addresses[0]
    network_tier = "PREMIUM"
  }]
}

resource "google_compute_firewall" "wireguard_firewall" {
  name          = "wireguard-allow"
  project       = var.project_id
  network       = module.vpc.network_name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  target_tags = ["wireguard"]
}
