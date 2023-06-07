data "google_compute_network" "network" {
  name = var.vpc_name
  project = var.project_id
}

module "private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "~> 10.0"

  project_id  = var.project_id
  vpc_network = var.vpc_name
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
  vpc_network         = data.google_compute_network.network.self_link
  allocated_ip_range  = module.private_service_access.google_compute_global_address_name
  assign_public_ip    = false

  additional_databases = concat(
    [for database_name in local.database_names : 
      {
        name      = database_name
        charset   = ""
        collation = ""
      }
    ],
    [for database_name in local.database_names :
      {
        name = "${database_name}-dev"
        charset = ""
        collation = ""
      }
    ]
  )

  deletion_protection = false

  module_depends_on = [module.private_service_access.peering_completed]
}
