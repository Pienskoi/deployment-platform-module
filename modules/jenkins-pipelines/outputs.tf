output "ca_certificate" {
  description = "Certificate representing a Certificate Authority (CA)"
  value       = tls_self_signed_cert.ca_cert.cert_pem
}

output "dns_name_servers" {
  value = module.dns_public_zone[*].name_servers
}

output "domain" {
  value = local.domain
}

output "jenkins_webhook_static_ip" {
  value = module.global_public_address.addresses[1]
}