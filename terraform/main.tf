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
  network           = module.vpc.network_self_link
  subnetwork        = "project-subnet"
  ip_range_pods     = "ip-range-pods-infr"
  ip_range_services = "ip-range-svc-infr"

  cluster_autoscaling = {
    enabled = true
  }

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "e2-medium"
    image_type   = "COS_CONTAINERD"
    autoscaling  = true
    min_count    = 1
    max_count    = 3
  }]
}

module "gke_qa" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id        = var.project_id
  name              = var.gke_qa_cluster_name
  region            = var.region
  network           = module.vpc.network_self_link
  subnetwork        = "project-subnet"
  ip_range_pods     = "ip-range-pods-qa"
  ip_range_services = "ip-range-svc-cqa"

  cluster_autoscaling = {
    enabled = true
  }

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "e2-medium"
    image_type   = "COS_CONTAINERD"
    autoscaling  = true
    min_count    = 1
    max_count    = 10
  }]
}

module "gke_ci" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id        = var.project_id
  name              = var.gke_ci_cluster_name
  region            = var.region
  network           = module.vpc.network_self_link
  subnetwork        = "project-subnet"
  ip_range_pods     = "ip-range-pods-ci"
  ip_range_services = "ip-range-svc-ci"

  cluster_autoscaling = {
    enabled = true
  }

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "e2-medium"
    image_type   = "COS_CONTAINERD"
    autoscaling  = true
    min_count    = 1
    max_count    = 10
  }]
}

module "workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 20.0"
  
  project_id = var.project_id
  name       = "mysql_workload_identity"
  namespace  = "petclinic"
  roles      = ["roles/cloudsql.client"]
}

module "service_accounts" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.1"

  project_id    = var.project_id
  generate_keys = true

  names = [
    "ansible-control-node",
    "ansible-managed-node",
    "docker-registry-storage",
    "gke-deploy"
  ]

  descriptions = [
    "Service account used by Ansible control node",
    "Service account used by Ansible managed nodes",
    "Service account used by Docker registry to access GCS",
    "Service account used to deploy application to GKE clusters"
  ]
}

module "service_account_iam_bindings" {
  source  = "terraform-google-modules/iam/google//modules/service_accounts_iam"
  version = "~> 7.4"

  service_accounts = [module.service_accounts.emails["ansible-managed-node"]]
  project          = var.project_id

  bindings = {
    "roles/iam.serviceAccountUser" = [
      module.service_accounts.iam_emails["ansible-control-node"]
    ]
  }
}

module "project_iam_bindings" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 7.4"

  projects = [var.project_id]

  bindings = {
    "roles/compute.viewer"       = [module.service_accounts.iam_emails["ansible-control-node"]]
    "roles/compute.osAdminLogin" = [module.service_accounts.iam_emails["ansible-control-node"]]
    "" = [module.service_accounts.iam_emails["gke-deploy"]] 
  }
}

resource "random_id" "bucket_name_suffix" {
  byte_length = 4
}

module "bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 3.2"

  name       = "docker-registry-bucket-${random_id.bucket_name_suffix}"
  project_id = var.project_id
  location   = var.region
  iam_members = [{
    role   = "roles/storage.objectAdmin"
    member = module.service_accounts.iam_emails["docker-registry-storage"]
  }]
}

module "private_service_access" {
  source  = "terraform-google-modules/sql-db/google//modules/private_service_access"
  version = "~> 10.0"  
  
  project_id  = var.project_id
  vpc_network = module.vpc.network_name
}

module "safer_mysql_db" {
  source  = "terraform-google-modules/sql-db/google//modules/safer_mysql"
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
    name = var.sql_database_name
  }]

  module_depends_on = [module.private_service_access.peering_completed]
}

module "build_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.7"

  project_id   = var.project_id
  region       = var.region
  subnetwork   = "project-subnet"
  source_image = "debian-cloud/debian-10"
  machine_type = "n1-standard-1"

  service_account = {
    email  = module.service_accounts.emails["ansible-managed-node"]
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
  subnetwork        = "project-subnet"
  hostname          = "ansible-build-node"
  instance_template = module.build_instance_template.self_link
}

module "deploy_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.7"

  project_id   = var.project_id
  region       = var.region
  subnetwork   = "project-subnet"
  source_image = "debian-cloud/debian-10"
  machine_type = "n1-standard-1"

  service_account = {
    email  = module.service_accounts.emails["ansible-managed-node"]
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
  subnetwork        = "project-subnet"
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

module "dns_public_zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 4.1"

  project_id = var.project_id
  type       = "public"
  name       = "spring-petclinic-tk"
  domain     = "spring-petclinic.tk."

  private_visibility_config_networks = [module.vpc.network_self_link]
}

module "private_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id       = var.project_id
  region           = var.region
  subnetwork       = "project-subnet"
  enable_cloud_dns = true
  dns_domain       = module.dns_private_zone.domain
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

module "public_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id       = var.project_id
  region           = var.region
  subnetwork       = "project-subnet"
  enable_cloud_dns = true
  dns_domain       = module.dns_private_zone.domain
  dns_managed_zone = module.dns_private_zone.name
  dns_project      = var.project_id
  address_type     = "EXTERNAL"

  names = [
    "spring-petclinic-static-ip",
    "jenkins-webhook-static-ip"
  ]

  dns_short_names = [
    ""
  ]
}

module "vpn_ha" {
  source = "terraform-google-modules/vpn/google//modules/vpn_ha"
  version = "~> 2.2"

  project_id  = var.project_id
  region  = var.region
  network         = module.vpc.network_self_link
  name            = "project-vpc-to-onprem"

  peer_external_gateway = {
    redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
    interfaces = [{
        id = 0
        ip_address = var.onprem_router_ip_address
    }]
  }
  router_asn = 64514
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.1"
        asn     = 64513
      }
      bgp_peer_options  = null
      bgp_session_range = "169.254.1.2/30"
      ike_version       = 2
      vpn_gateway_interface = 0
      peer_external_gateway_interface = 0
      shared_secret     = var.vpn_shared_secret
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.1"
        asn     = 64513
      }
      bgp_peer_options  = null
      bgp_session_range = "169.254.2.2/30"
      ike_version       = 2
      vpn_gateway_interface = 1
      peer_external_gateway_interface = 0
      shared_secret     = var.vpn_shared_secret
    }
  }
}
