variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "services" {
  type = list(
    object({
      name       = string
      owner      = string
      repository = string
      type       = string
      path       = optional(string)
      port       = optional(number, 80)
      args       = optional(list(string), [])
      database   = optional(bool, false)
    })
  )
}

variable "subnet_name" {
  type = string
}

variable "domain" {
  type    = string
  default = ""
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

variable "jenkins_admin_username" {
  type = string
}

variable "jenkins_admin_password" {
  type = string
}
