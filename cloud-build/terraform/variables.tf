variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "gke_cluster_name" {
  type = string
}

variable "sql_database_name" {
  type = string
}

variable "sql_user_name" {
  type      = string
  sensitive = true
}

variable "sql_user_password" {
  type      = string
  sensitive = true
}

variable "domain" {
  type = string
}
