locals {
  environments = ["production", "development"]
  domain       = var.domain == "" ? "${replace(module.global_public_address.addresses[0], ".", "-")}.nip.io" : var.domain
}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset(concat(["jenkins"], local.environments))

  metadata {
    name = each.value
  }
}

resource "kubernetes_ingress_v1" "app_external_ingress" {
  metadata {
    name      = "app-ingress"
    namespace = kubernetes_namespace.namespaces["production"].metadata[0].name
    annotations = {
      "kubernetes.io/ingress.global-static-ip-name" = module.global_public_address.names[0]
      "networking.gke.io/managed-certificates"      = "managed-cert"
      "kubernetes.io/ingress.class"                 = "gce"
    }
  }

  spec {
    rule {
      http {
        dynamic "path" {
          for_each = toset(var.services)

          content {
            backend {
              service {
                name = "${path.value.name}-service"
                port {
                  number = path.value.port
                }
              }
            }

            path_type = "Prefix"
            path      = "/${coalesce(path.value.path, path.value.name)}"
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "app_internal_ingress" {
  metadata {
    name = "app-ingress"
    annotations = {
      "kubernetes.io/ingress.regional-static-ip-name" = module.private_address.names[1]
      "kubernetes.io/ingress.class"                   = "gce-internal"
      "ingress.gcp.kubernetes.io/pre-shared-cert"     = google_compute_region_ssl_certificate.google_project_cert.name
      "kubernetes.io/ingress.allow-http"              = "false"
    }
    namespace = kubernetes_namespace.namespaces["development"].metadata[0].name
  }

  spec {
    rule {
      http {
        dynamic "path" {
          for_each = toset(var.services)

          content {
            backend {
              service {
                name = "${path.value.name}-service"
                port {
                  number = path.value.port
                }
              }
            }

            path_type = "Prefix"
            path      = "/${coalesce(path.value.path, path.value.name)}/*"
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "managed_certificate" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "managed-cert"
      namespace = kubernetes_namespace.namespaces["production"].metadata[0].name
    }
    spec = {
      domains = [local.domain]
    }
  }
}

resource "kubernetes_secret" "jenkins_admin_credentials" {
  metadata {
    name      = "user-credentials"
    namespace = kubernetes_namespace.namespaces["jenkins"].metadata[0].name
  }

  data = {
    admin-username = var.jenkins_admin_username
    admin-password = var.jenkins_admin_password
  }
}

resource "kubernetes_secret" "prod_mysql_secrets" {
  for_each = toset(local.database_names)

  metadata {
    name      = "${each.value}-mysql-secret"
    namespace = kubernetes_namespace.namespaces["production"].metadata[0].name
  }

  data = {
    MYSQL_PASS = module.safer_mysql_db.generated_user_password
  }
}

resource "kubernetes_secret" "dev_mysql_secrets" {
  for_each = toset(local.database_names)

  metadata {
    name      = "${each.value}-mysql-secret"
    namespace = kubernetes_namespace.namespaces["development"].metadata[0].name
  }

  data = {
    MYSQL_PASS = module.safer_mysql_db.generated_user_password
  }
}
