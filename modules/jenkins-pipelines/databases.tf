resource "google_sql_database" "databases" {
  for_each = toset(local.service_names)

  name     = each.value
  instance = var.database_instance_name
}

resource "random_password" "user_passwords" {
  for_each = toset(local.service_names)

  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+"
}

resource "google_sql_user" "database_users" {
  for_each = toset(local.service_names)

  name     = each.value
  instance = var.database_instance_name
  host     = "~cloudsqlproxy"
  password = random_password.user_passwords[each.value].result
}
