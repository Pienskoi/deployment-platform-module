output "sql_connection_name" {
  value     = module.safer_mysql_db.instance_connection_name
  sensitive = true
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
