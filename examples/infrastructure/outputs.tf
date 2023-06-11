output "wireguard_server_public_ip" {
  description = "Wireguard server public IP address"
  value       = module.deployment_infrastructure.wireguard_server_public_ip
}

output "wireguard_client_private_key" {
  description = "Wireguard client private key"
  value       = module.deployment_infrastructure.wireguard_client_private_key
  sensitive   = true
}

output "wireguard_server_public_key" {
  description = "Wireguard server public key"
  value       = module.deployment_infrastructure.wireguard_server_public_key
}

output "cluster_endpoint" {
  value     = module.deployment_infrastructure.cluster_endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.deployment_infrastructure.cluster_ca_certificate
  sensitive = true
}
