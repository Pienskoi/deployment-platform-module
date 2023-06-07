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

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }

    wireguard = {
      source  = "OJFord/wireguard"
      version = "0.2.2"
    }
  }
}
