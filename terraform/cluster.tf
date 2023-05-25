module "gke_cluster" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~> 20.0"

  project_id        = var.project_id
  name              = var.gke_cluster_name
  region            = var.region
  zones             = [var.zone]
  network           = module.vpc.network_name
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  ip_range_pods     = "gke-ip-range-pods"
  ip_range_services = "gke-ip-range-svc"

  node_pools = [
    {
      name         = "default-node-pool"
      machine_type = "n2-standard-2"
      image_type   = "COS_CONTAINERD"
      autoscaling  = true
      min_count    = 1
      max_count    = 3
    },
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
