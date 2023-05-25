resource "random_string" "bucket_name_suffix" {
  length  = 4
  special = false
  upper   = false
}

module "bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 3.2"

  name       = "docker-registry-bucket-${random_string.bucket_name_suffix.result}"
  project_id = var.project_id
  location   = var.region

  force_destroy = true
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = module.bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.service_accounts.service_accounts_map["docker-registry-storage"].email}"
}
