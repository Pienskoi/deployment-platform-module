variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "gke_infrastructure_cluster_name" {
  type = string
}

variable "gke_ci_cluster_name" {
  type = string
}

variable "gke_qa_cluster_name" {
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

variable "onprem_router_ip_address" {
  type      = string
  sensitive = true
}

variable "vpn_shared_secret" {
  type      = string
  sensitive = true
}