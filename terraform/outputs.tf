output "sql_connection_name" {
  value     = module.safer_mysql_db.instance_connection_name
  sensitive = true
}

output "dns_name_servers" {
  value = module.dns_public_zone.name_servers
}

output "jenkins_webhook_static_ip" {
  value = module.global_public_address.addresses[1]
}

output "wireguard_server_public_ip" {
  description = "Wireguard server public IP address"
  value       = module.regional_public_address.addresses[0]
}

output "wireguard_client_private_key" {
  description = "Wireguard client private key"
  value       = wireguard_asymmetric_key.wg_client_key.private_key
  sensitive   = true
}

output "wireguard_server_public_key" {
  description = "Wireguard server public key"
  value       = wireguard_asymmetric_key.wg_server_key.public_key
}

output "ca_certificate" {
  description = "Certificate representing a Certificate Authority (CA)"
  value       = tls_self_signed_cert.ca_cert.cert_pem
}