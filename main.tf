terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>5.0"
    }
  }
}

provider "google" {
  region  = var.gcp_region
  project = var.gcp_project
}

module "vpc" {
  source         = "./vpc"
  name           = var.vpc_configs.name
  webapp_ip_cidr = var.vpc_configs.webapp_ip_cidr
  db_ip_cidr     = var.vpc_configs.db_ip_cidr
  routing_mode   = var.vpc_configs.routing_mode
  region         = var.vpc_configs.region
}

module "sql" {
  source               = "./sql"
  db_name              = var.sql_configs.db_name
  db_version           = var.sql_configs.db_version
  deletion_protection  = var.sql_configs.deletion_protection
  instance_name_prefix = var.sql_configs.instance_name_prefix
  disk_size            = var.sql_configs.disk_size
  disk_type            = var.sql_configs.disk_type
  private_network      = module.vpc.vpc_id
  instance_region      = var.sql_configs.instance_region
  availability_type    = var.sql_configs.availability_type
  consumer_projects    = var.sql_configs.consumer_projects
  sql_user             = var.sql_configs.sql_user
}

resource "google_compute_address" "internal_ip" {
  name         = var.internal_ip_name
  address_type = "INTERNAL"
  address      = var.internal_ip_address
  subnetwork   = module.vpc.db_subnet_name
  region       = var.gcp_region
}
data "google_sql_database_instance" "mysql_instance" {
  name = module.sql.db_instance_name
}


resource "google_compute_forwarding_rule" "forwarding_rule" {
  name   = "psforwardingrule"
  target = data.google_sql_database_instance.mysql_instance.psc_service_attachment_link
  # target                = "all-apis"
  network               = module.vpc.vpc_id
  ip_address            = google_compute_address.internal_ip.self_link
  load_balancing_scheme = ""
  region                = var.gcp_region
}

module "vm" {
  source                 = "./vm"
  name                   = var.vm_configs.name
  machine_type           = var.vm_configs.machine_type
  zone                   = var.vm_configs.zone
  boot_disk_image        = var.vm_configs.boot_disk_image
  subnetwork             = module.vpc.webapp_subnet_name
  boot_disk_size         = var.vm_configs.boot_disk_size
  boot_disk_type         = var.vm_configs.boot_disk_type
  tags                   = module.vpc.webapp_firewall_tags
  network_tier           = var.vm_configs.network_tier
  startup_script_content = <<-EOT
      #!/bin/bash

      touch /tmp/.env

      echo "PROD_DB_NAME=${module.sql.db_name}" >> /tmp/.env
      echo "PROD_DB_USER=${module.sql.db_instance_user}" >> /tmp/.env
      echo "PROD_DB_PASS=${module.sql.db_instance_password}" >> /tmp/.env
      echo "PROD_HOST=${var.internal_ip_address}" >> /tmp/.env
      echo "NODE_ENV=production" >> /tmp/.env

      sudo mv /tmp/.env /opt/webapp/app
      sudo chown csye6225:csye6225 /opt/webapp/app/.env

      EOT

}
