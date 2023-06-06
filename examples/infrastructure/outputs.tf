output "wireguard_server_public_ip" {
  value = module.deployment_platform.wireguard_server_public_ip
}

output "wireguard_client_private_key" {
  description = "Wireguard client private key"
  value       = module.deployment_platform.wireguard_client_private_key
  sensitive   = true
}

output "wireguard_server_public_key" {
  description = "Wireguard server public key"
  value       = module.deployment_platform.wireguard_server_public_key
}
