terraform {
  required_version = ">= 0.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.67.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.67.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.21.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.10.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}
