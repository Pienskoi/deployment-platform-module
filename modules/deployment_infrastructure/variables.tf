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
  type    = string
  default = "project-cluster"
}

variable "vpc_name" {
  type    = string
  default = "project-vpc"
}
