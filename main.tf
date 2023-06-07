locals {
  service_names = [for service in var.services : service.name]
  database_names = [for service in var.services : service.name if service.database]
  service_files = [
    for service in var.services : {
      name = service.name
      jenkinsfile = templatefile("${path.module}/templates/Jenkinsfile.tftpl", {
        registry_host  = "${var.region}-docker.pkg.dev"
        project_id     = var.project_id
        repository     = google_artifact_registry_repository.project_repo.name
        service_name   = service.name
        service_type   = service.type
        cluster_name   = var.cluster_name
        cluster_location   = var.region
        prod_namespace = "production"
        dev_namespace  = "development"
      }),
      prod_values = templatefile("${path.module}/templates/values.tftpl", {
        image                 = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.project_repo.name}/${service.name}"
        service_account_name  = service.name
        port                  = service.port
        args                  = service.args
        path                  = coalesce(service.path, service.name)
        autoscaling           = true
        replicas              = 0
        mysql_enabled         = service.database
        mysql_database        = service.name
        mysql_user            = "default"
        mysql_secret          = "${service.name}-mysql-secret"
        mysql_connection_name = module.safer_mysql_db.instance_connection_name
      }),
      dev_values = templatefile("${path.module}/templates/values.tftpl", {
        image                 = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.project_repo.name}/${service.name}"
        service_account_name  = service.name
        port                  = service.port
        args                  = service.args
        path                  = coalesce(service.path, service.name)
        autoscaling           = false
        replicas              = 1
        mysql_enabled         = service.database
        mysql_database        = "${service.name}-dev"
        mysql_user            = "default"
        mysql_secret          = "${service.name}-mysql-secret"
        mysql_connection_name = module.safer_mysql_db.instance_connection_name
      })
    }
  ]
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "4.3.24"
  namespace  = kubernetes_namespace.namespaces["jenkins"].metadata[0].name

  values = [
    file("${path.module}/files/config.yaml"),
    templatefile("${path.module}/templates/jobs.tftpl", {
      services = var.services
    }),
    templatefile("${path.module}/templates/files.tftpl", {
      service_files = local.service_files
      files_path = "${path.module}/files"
    })
  ]
}
