#!/bin/bash

# Provide next arguments in KEY=VALUE style:
# 
# PROJECT_ID - GCP Project ID
# REGION - Region where all regional resources will bedeployed
# ZONE - Zone where all zonal resiurces will be deployed
# JENKINS_ADMIN_USERNAME - Jenkins admin username
# JENKINS_ADMIN_PASSWORD - Jenkins admin password
# DOMAIN - Global domain name for spring-petclinic CI environment
# SERVICE_NAME - Name of service
# SERVICE_OWNER - Owner of service GitHub repository
# SERVICE_REPO - Name of service GitHub repository
# SERVICE_TYPE - Type of service (e.g. java-17-maven)
# SERVICE_PORT - Port of service

KEYS=(
  "PROJECT_ID"
  "REGION"
  "ZONE"
  "JENKINS_ADMIN_USERNAME"
  "JENKINS_ADMIN_PASSWORD"
  "DOMAIN"
  "SERVICE_NAME"
  "SERVICE_OWNER"
  "SERVICE_REPO"
  "SERVICE_TYPE"
  "SERVICE_PORT"
  "SERVICE_DB_ENABLED"
)
for ARGUMENT in "$@"; do
  KEY="$(echo "${ARGUMENT}" | cut -f1 -d=)"

  KEY_LENGTH=${#KEY}
  VALUE="${ARGUMENT:${KEY_LENGTH}+1}"

  declare "${KEY}"="${VALUE}"
done
for KEY in "${KEYS[@]}"; do
  if [ -z ${!KEY+x} ]; then 
    printf "${KEY}: "
    read "${KEY}"
  fi
done

gcloud config set core/project "${PROJECT_ID}"

cd ../deployment_infrastructure
terraform init -upgrade
cat <<EOF > terraform.tfvars
project_id        = "${PROJECT_ID}"
region            = "${REGION}"
zone              = "${ZONE}"
EOF
terraform plan -out ./infrastructure.tfplan
terraform apply /infrastructure.tfplan

WIREGUARD_IP="$(terraform output -raw wireguard_server_public_ip)"
WIREGUARD_PRIVATE_KEY="$(terraform output -raw wireguard_client_private_key)"
WIREGUARD_PUBLIC_KEY="$(terraform output -raw wireguard_server_public_key)"
WIREGUARD_DNS="$(gcloud compute addresses list --filter='purpose:DNS_RESOLVER AND subnetwork:project-subnet' --format='get(address)')"
CLUSTER_ENDPOINT="$(terraform output -raw cluster_endpoint)"
CLUSTER_CA_CERTIFICATE="$(terraform output -raw cluster_ca_certificate)"

cd ../simple_script
cat <<EOF > ./wg0-client.conf
[Interface]
Address = 10.0.10.2/32
PrivateKey = ${WIREGUARD_PRIVATE_KEY}
DNS = ${WIREGUARD_DNS}
MTU = 1380

[Peer]
PublicKey = ${WIREGUARD_PUBLIC_KEY}
Endpoint = ${WIREGUARD_IP}:51820
AllowedIPs = 10.0.10.0/24, 10.10.10.0/24, 10.0.0.0/28
PersistentKeepalive = 21
EOF
sudo wg-quick up ./wg0-client.conf

cd ../deployment_platform
terraform init -upgrade
cat <<EOF > terraform.tfvars
project_id        = "${PROJECT_ID}"
region            = "${REGION}"
zone              = "${ZONE}"
services = [
  {
    name       = "${SERVICE_NAME}"
    owner      = "${SERVICE_OWNER}"
    repository = "${SERVICE_REPO}"
    type       = "${SERVICE_TYPE}"
    port       = ${SERVICE_PORT}
    database   = ${SERVICE_DB_ENABLED}
  }
]
domain                 = "${DOMAIN}"
jenkins_admin_username = "${JENKINS_ADMIN_USERNAME}"
jenkins_admin_password = "${JENKINS_ADMIN_PASSWORD}"
cluster_endpoint       = "${CLUSTER_ENDPOINT}"
cluster_ca_certificate = "${CLUSTER_CA_CERTIFICATE}"
EOF
terraform plan -out ./infrastructure.tfplan
terraform apply /infrastructure.tfplan

DOMAIN="$(terraform output domain)"
NAMESERVERS="$(terraform output dns_name_servers)"
JENKINS_WEBHOOK_IP="$(terraform output -raw jenkins_webhook_static_ip)"

terraform output -raw ca_certificate | sudo tee /usr/local/share/ca-certificates/ProjectCA.crt
sudo update-ca-certificates

echo "Domain: ${DOMAIN}"
echo "Add nameservers to domain config (if not empty):
${NAMESERVERS}"
echo "Create GitHub webhook with Push and Pull Request events to URL:
http://${JENKINS_WEBHOOK_IP}/github-webhook/"
