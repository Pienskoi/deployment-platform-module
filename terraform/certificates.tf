resource "tls_private_key" "ca_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_private_key.private_key_pem

  subject {
    common_name = "Project CA"
  }

  validity_period_hours = 2190
  early_renewal_hours   = 730
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
}

resource "tls_private_key" "project_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "project_cert_request" {
  private_key_pem = tls_private_key.project_private_key.private_key_pem

  subject {
    common_name = var.internal_domain
  }

  dns_names = [
    "docker-registry.${var.internal_domain}",
    "jenkins.${var.internal_domain}",
    "qa.${var.internal_domain}"
  ]
}

resource "tls_locally_signed_cert" "project_cert" {
  cert_request_pem   = tls_cert_request.project_cert_request.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 2190
  early_renewal_hours   = 730

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "google_compute_region_ssl_certificate" "google_project_cert" {
  name    = "project-cert"
  project = var.project_id
  region  = var.region

  private_key = tls_private_key.project_private_key.private_key_pem
  certificate = tls_locally_signed_cert.project_cert.cert_pem


  lifecycle {
    create_before_destroy = true
  }
}
