output "gke_deploy_sa_key" {
  value     = module.service_accounts.keys["jenkins"]
  sensitive = true
}

output "sql_connection_name" {
  value     = module.safer_mysql_db.instance_connection_name
  sensitive = true
}

output "sql_service_account" {
  value     = module.workload_identity.gcp_service_account_email
  sensitive = true
}

output "dns_name_servers" {
  value = module.dns_public_zone.name_servers
}

output "jenkins_webhook_static_ip" {
  value = module.global_public_address.addresses[1]
}

output "wireguard_server_public_ip" {
  value = module.regional_public_address.addresses[0]
}

output "ca_certificate" {
  description = "Certificate representing a Certificate Authority (CA)"
  value       = tls_self_signed_cert.ca_cert.cert_pem
}