output "os_login_sa_key" {
  value     = module.service_accounts.keys["os-login"]
  sensitive = true
}

output "os_login_ssh_username" {
  value = "sa_${module.service_accounts.service_accounts_map["os-login"].unique_id}"
}

output "dns_name_servers" {
  value = module.dns_public_zone.name_servers
}

output "wireguard_server_public_ip" {
  value = module.regional_public_address.addresses[0]
}
