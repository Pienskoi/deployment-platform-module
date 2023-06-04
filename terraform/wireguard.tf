resource "google_dns_policy" "project_dns_policy" {
  name                      = "project-dns-policy"
  enable_inbound_forwarding = true

  networks {
    network_url = module.vpc.network_id
  }
}

resource "wireguard_asymmetric_key" "wg_server_key" {
}

resource "wireguard_asymmetric_key" "wg_client_key" {
}

module "wireguard_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.7"

  project_id           = var.project_id
  region               = var.region
  subnetwork           = module.subnets.subnets["${var.region}/project-subnet"].name
  source_image_family  = "debian-10"
  source_image_project = "debian-cloud"
  machine_type         = "n1-standard-1"
  can_ip_forward       = true
  tags                 = ["wireguard"]

  startup_script = templatefile("${path.module}/templates/wg_server_script.tftpl",
    {
      server_private_key = wireguard_asymmetric_key.wg_server_key.private_key
      client_public_key  = wireguard_asymmetric_key.wg_client_key.public_key
    }
  )

  service_account = {
    email  = google_service_account.wireguard_sa.email
    scopes = ["cloud-platform"]
  }
}

module "wireguard_compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.7"

  region            = var.region
  zone              = var.zone
  subnetwork        = module.subnets.subnets["${var.region}/project-subnet"].name
  hostname          = "wireguard"
  instance_template = module.wireguard_instance_template.self_link

  access_config = [{
    nat_ip       = module.regional_public_address.addresses[0]
    network_tier = "PREMIUM"
  }]
}

resource "google_compute_firewall" "wireguard_allow" {
  name          = "wireguard-allow"
  project       = var.project_id
  network       = module.vpc.network_name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  target_tags = ["wireguard"]
}
