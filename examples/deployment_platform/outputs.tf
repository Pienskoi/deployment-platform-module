output "ca_certificate" {
  description = "Certificate representing a Certificate Authority (CA)"
  value       = module.deployment_platform.ca_certificate
}

output "dns_name_servers" {
  value = module.deployment_platform.dns_name_servers
}

output "domain" {
  value = module.deployment_platfom.domain
}

output "jenkins_webhook_static_ip" {
  value = module.deployment_platform.jenkins_webhook_static_ip
}