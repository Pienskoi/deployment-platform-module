resource "google_artifact_registry_repository" "project_repo" {
  location      = var.region
  repository_id = "project-repo"
  description   = "Project repository for Docker images and Helm charts"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "jenkins_registry_iam_member" {
  provider = google-beta

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.project_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${module.jenkins_workload_identity.gcp_service_account_email}"
}