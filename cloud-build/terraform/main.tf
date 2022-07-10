module "project_vpc" {
  source  = "terraform-google-modules/network/google//modules/vpc"
  version = "~> 5.0"

  network_name = "project-vpc"
  project_id   = var.project_id
}

module "subnets" {
  source  = "terraform-google-modules/network/google//modules/subnets-beta"
  version = "~> 5.0"

  project_id   = var.project_id
  network_name = module.project_vpc.network_name

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
  network       = module.project_vpc.network_name
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
  network = module.project_vpc.network_self_link

  nats = [{
    name = "project-nat"
  }]
}

module "gke_cluster" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id            = var.project_id
  name                  = var.gke_cluster_name
  region                = var.region
  zones                 = [var.zone]
  network               = module.project_vpc.network_name
  subnetwork            = module.subnets.subnets["${var.region}/project-subnet"].name
  ip_range_pods         = "gke-ip-range-pods"
  ip_range_services     = "gke-ip-range-svc"
  grant_registry_access = true

  node_pools = [
    {
      name         = "app-node-pool"
      machine_type = "n1-standard-1"
      image_type   = "COS_CONTAINERD"
      autoscaling  = true
      min_count    = 1
      max_count    = 10
    }
  ]

  master_ipv4_cidr_block = "10.0.0.0/28"
  master_authorized_networks = [
    {
      cidr_block   = module.subnets.subnets["${var.region}/project-subnet"].ip_cidr_range
      display_name = "VPC project-subnet"
    },
    {
      cidr_block   = "${google_compute_global_address.cloudbuild_ip_range.address}/${google_compute_global_address.cloudbuild_ip_range.prefix_length}"
      display_name = "VPC cloudbuild"
    }
  ]
}

module "workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 20.0"

  project_id          = var.project_id
  name                = "mysql-workload-identity"
  namespace           = "petclinic-ci"
  use_existing_k8s_sa = true
  k8s_sa_name         = "sql-proxy-sa"
  annotate_k8s_sa     = false
  roles               = ["roles/cloudsql.client"]

  depends_on = [module.gke_cluster.name]
}

module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.1"

  project_id    = var.project_id
  generate_keys = true

  names = [
    "cloudbuild-build",
    "cloudbuild-deploy",
    "os-login"
  ]

  descriptions = [
    "Service account used by Cloud Build to push artifacts to Artifact Registry",
    "Service account used by Cloud Build to deploy application to GKE clusters",
    "Service account used to connect to instances by SSH"
  ]
}

resource "google_project_iam_binding" "cloudbuild_sa_iam" {
  project = var.project_id
  role    = "roles/logging.logWriter"

  members = [
    "serviceAccount:${module.service_accounts.service_accounts_map["cloudbuild-build"].email}",
    "serviceAccount:${module.service_accounts.service_accounts_map["cloudbuild-deploy"].email}"
  ]
}

resource "google_project_iam_member" "cloudbuild_deploy_sa_iam" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["cloudbuild-deploy"].email}"
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

resource "google_project_iam_member" "os_login_sa_iam" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "serviceAccount:${module.service_accounts.service_accounts_map["os-login"].email}"
}

module "private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "~> 10.0"

  project_id  = var.project_id
  vpc_network = module.project_vpc.network_name

  depends_on = [module.project_vpc]
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

  vpc_network        = module.project_vpc.network_self_link
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

module "dns_private_zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "private"
  name       = "project-com"
  domain     = "project.com."

  private_visibility_config_networks = [module.project_vpc.network_self_link]
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
  names            = ["internal-spring-petclinic-ip"]
  dns_short_names  = ["qa"]
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
  names        = ["spring-petclinic-static-ip"]
}

module "dns_public_zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "public"
  name       = "spring-petclinic-tk"
  domain     = "${var.domain}."

  private_visibility_config_networks = [module.project_vpc.network_self_link]

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
    network_url = module.project_vpc.network_id
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
  startup_script       = file("./wireguard-script.sh")

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

resource "google_compute_firewall" "wireguard_allow" {
  name          = "wireguard-allow"
  project       = var.project_id
  network       = module.project_vpc.network_name
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

resource "google_artifact_registry_repository" "project_repo" {
  provider = google-beta

  location      = var.region
  repository_id = "project-repo"
  description   = "Project repository for Docker images and Helm charts"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "cloudbuild_build_sa_iam" {
  provider = google-beta

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.project_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${module.service_accounts.service_accounts_map["cloudbuild-build"].email}"
}

module "cloudbuild_vpc" {
  source  = "terraform-google-modules/network/google//modules/vpc"
  version = "~> 5.0"

  network_name = "cloudbuild-vpc"
  project_id   = var.project_id
}

resource "google_compute_global_address" "cloudbuild_ip_range" {
  name          = "google-managed-services-${module.cloudbuild_vpc.network_name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = module.cloudbuild_vpc.network_id
}

resource "google_service_networking_connection" "cloudbuild_service_networking_connection" {
  network                 = module.cloudbuild_vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_ip_range.name]
}

resource "google_compute_network_peering_routes_config" "cloudbuild_peering_export_custom_routes" {
  peering = google_service_networking_connection.cloudbuild_service_networking_connection.peering
  network = module.cloudbuild_vpc.network_name

  import_custom_routes = false
  export_custom_routes = true
}

resource "google_compute_network_peering_routes_config" "gke_peering_export_custom_routes" {
  peering = module.gke_cluster.peering_name
  network = module.project_vpc.network_name

  import_custom_routes = false
  export_custom_routes = true
}

resource "google_cloudbuild_worker_pool" "cloudbuild_private_pool" {
  name     = "project-private-pool"
  location = var.region

  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-medium"
    no_external_ip = false
  }

  network_config {
    peered_network = module.cloudbuild_vpc.network_id
  }

  depends_on = [google_service_networking_connection.cloudbuild_service_networking_connection]
}

module "project_vpn_ha" {
  source  = "terraform-google-modules/vpn/google//modules/vpn_ha"
  version = "~> 2.3"

  project_id       = var.project_id
  region           = var.region
  network          = module.project_vpc.network_self_link
  name             = "project-vpc-to-cloudbuild-vpc"
  peer_gcp_gateway = module.cloudbuild_vpn_ha.self_link
  router_asn       = 64514

  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.1"
        asn     = 64513
      }
      bgp_peer_options = {
        advertise_groups = null
        advertise_ip_ranges = {
          "${module.gke_cluster.master_ipv4_cidr_block}" = "GKE cluster control plane VPC network"
        }
        advertise_mode = "CUSTOM"
        route_priority = 1000
      }
      bgp_session_range               = "169.254.1.2/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      shared_secret                   = ""
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.1"
        asn     = 64513
      }
      bgp_peer_options = {
        advertise_groups = null
        advertise_ip_ranges = {
          "${module.gke_cluster.master_ipv4_cidr_block}" = "GKE cluster control plane VPC network"
        }
        advertise_mode = "CUSTOM"
        route_priority = 1000
      }
      bgp_session_range               = "169.254.2.2/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      shared_secret                   = ""
    }
  }
}

module "cloudbuild_vpn_ha" {
  source  = "terraform-google-modules/vpn/google//modules/vpn_ha"
  version = "~> 2.3"

  project_id       = var.project_id
  region           = var.region
  network          = module.cloudbuild_vpc.network_self_link
  name             = "cloudbuild-vpc-to-project-vpc"
  peer_gcp_gateway = module.project_vpn_ha.self_link
  router_asn       = 64513

  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.2"
        asn     = 64514
      }
      bgp_peer_options = {
        advertise_groups = null
        advertise_ip_ranges = {
          "${google_compute_global_address.cloudbuild_ip_range.address}/${google_compute_global_address.cloudbuild_ip_range.prefix_length}" = "Cloud Build private pool VPC network"
        }
        advertise_mode = "CUSTOM"
        route_priority = 1000
      }
      bgp_session_range               = "169.254.1.1/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      shared_secret                   = module.project_vpn_ha.random_secret
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.2"
        asn     = 64514
      }
      bgp_peer_options = {
        advertise_groups = null
        advertise_ip_ranges = {
          "${google_compute_global_address.cloudbuild_ip_range.address}/${google_compute_global_address.cloudbuild_ip_range.prefix_length}" = "Cloud Build private pool VPC network"
        }
        advertise_mode = "CUSTOM"
        route_priority = 1000
      }
      bgp_session_range               = "169.254.2.1/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      shared_secret                   = module.project_vpn_ha.random_secret
    }
  }
}

resource "google_cloudbuild_trigger" "build_github_push_trigger" {
  name = "build-push"

  github {
    owner = "Pienskoi"
    name  = "DevOpsProject"
    push {
      branch = "^(main|develop)$"
    }
  }

  service_account = module.service_accounts.service_accounts_map["cloudbuild-build"].id
  filename        = "cloud-build/build.yaml"
  substitutions = {
    _ARTIFACT_REGISTRY_REPO = "${var.region}-docker.pkg.dev/${var.project_id}/project-repo"
  }
}

resource "google_cloudbuild_trigger" "build_github_pr_trigger" {
  name = "build-pr"

  github {
    owner = "Pienskoi"
    name  = "DevOpsProject"
    pull_request {
      branch = "^(main|develop)$"
    }
  }

  service_account = module.service_accounts.service_accounts_map["cloudbuild-build"].id
  filename        = "cloud-build/build.yaml"
  substitutions = {
    _ARTIFACT_REGISTRY_REPO = "${var.region}-docker.pkg.dev/${var.project_id}/project-repo"
  }
}

resource "google_cloudbuild_trigger" "deploy_ci_manual_trigger" {
  name = "deploy-ci"

  source_to_build {
    uri       = "https://github.com/Pienskoi/DevOpsProject"
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }

  git_file_source {
    path      = "cloud-build/deploy-ci.yaml"
    uri       = "https://github.com/Pienskoi/DevOpsProject"
    revision  = "refs/heads/main"
    repo_type = "GITHUB"
  }

  service_account = module.service_accounts.service_accounts_map["cloudbuild-deploy"].id
  substitutions = {
    _IMAGE_VERSION  = "latest"
    _IMAGE          = "${var.region}-docker.pkg.dev/${var.project_id}/project-repo/images/spring-petclinic:$${_IMAGE_VERSION}"
    _CHART          = "${var.region}-docker.pkg.dev/${var.project_id}/project-repo/charts/spring-petclinic-chart"
    _CHART_VERSION  = "1.0.0"
    _CLUSTER        = var.gke_cluster_name
    _CLUSTER_REGION = var.region
    _PRIVATEPOOL    = google_cloudbuild_worker_pool.cloudbuild_private_pool.id
  }
}

resource "google_cloudbuild_trigger" "deploy_qa_manual_trigger" {
  name = "deploy-qa"

  source_to_build {
    uri       = "https://github.com/Pienskoi/DevOpsProject"
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }

  git_file_source {
    path      = "cloud-build/deploy-qa.yaml"
    uri       = "https://github.com/Pienskoi/DevOpsProject"
    revision  = "refs/heads/main"
    repo_type = "GITHUB"
  }

  service_account = module.service_accounts.service_accounts_map["cloudbuild-deploy"].id
  substitutions = {
    _IMAGE_VERSION  = "latest"
    _IMAGE          = "${var.region}-docker.pkg.dev/${var.project_id}/project-repo/images/spring-petclinic:$${_IMAGE_VERSION}"
    _CHART          = "${var.region}-docker.pkg.dev/${var.project_id}/project-repo/charts/spring-petclinic-chart"
    _CHART_VERSION  = "1.0.0"
    _CLUSTER        = var.gke_cluster_name
    _CLUSTER_REGION = var.region
    _MYSQL_DATABASE = "petclinic"
    _MYSQL_USERNAME = "petclinic"
    _MYSQL_PASSWORD = "petclinic"
    _PRIVATEPOOL    = google_cloudbuild_worker_pool.cloudbuild_private_pool.id
  }
}

locals {
  secrets = {
    mysql-database   = var.sql_database_name
    mysql-username   = var.sql_user_name
    mysql-password   = var.sql_user_password
    mysql-connection = module.safer_mysql_db.instance_connection_name
    mysql-sa         = module.workload_identity.gcp_service_account_email
    domain           = var.domain
  }
}

resource "google_secret_manager_secret" "secret" {
  for_each = local.secrets

  secret_id = each.key

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "secret_version" {
  for_each = local.secrets

  secret = google_secret_manager_secret.secret[each.key].id

  secret_data = each.value
}

resource "google_secret_manager_secret_iam_member" "secret_iam_member" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.secret[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.service_accounts.service_accounts_map["cloudbuild-deploy"].email}"
}
