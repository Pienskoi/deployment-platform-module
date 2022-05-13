output "ansilbe_control_node_sa_key" {
  value     = module.service_accounts.keys["ansible-control-node"]
  sensitive = true
}

output "docker_registry_storage_sa_key" {
  value     = module.service_accounts.keys["docker-registry-storage"]
  sensitive = true
}

output "gke_deploy_sa_key" {
  value     = module.service_accounts.keys["gke-deploy"]
  sensitive = true
}

output "sql_connection_name" {
  value     = module.safer_mysql_db.instance_connection_name
  sensitive = true
}

output "sql_service_account_name" {
  value     = module.workload_identity.k8s_service_account_name
  sensitive = true
}
