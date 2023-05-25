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
