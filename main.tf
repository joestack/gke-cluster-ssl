terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# --- Network ---
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# --- GKE Cluster ---
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Nodes Service Account"
  project      = var.project_id
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name

  # ip_allocation_policy {
  #   cluster_secondary_range_name  = "pods"
  #   services_secondary_range_name = "services"
  # }

# The cluster is not staring because DB is not accessible
# Now I'll try this block
  # ADD THIS BLOCK to make the cluster VPC-Native
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/14"
    services_ipv4_cidr_block = "/20"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2
  project    = var.project_id

  node_config {
    machine_type    = "e2-standard-4"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    workload_metadata_config { mode = "GKE_METADATA" }
  }
}

# --- DNS & SSL Resources ---
data "google_dns_managed_zone" "artifactorytest" {
  name    = var.gcp_dns_zone 

  project = var.project_id
}

resource "google_compute_global_address" "artifactory_ip" {
  name    = "artifactory-ingress-ip"
  project = var.project_id
}

resource "google_dns_record_set" "artifactory" {
  name         = "${var.dns_hostname}.${data.google_dns_managed_zone.artifactorytest.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.artifactorytest.name
  project      = var.project_id
  rrdatas      = [google_compute_global_address.artifactory_ip.address]
}

resource "google_compute_managed_ssl_certificate" "artifactory" {
  name    = "artifactory-ssl-cert"
  project = var.project_id
  managed {
    domains = ["${var.dns_hostname}.${data.google_dns_managed_zone.artifactorytest.dns_name}"]

  }
}

# db.tf

# 1. Generate a secure password for the DB user
resource "random_password" "db_password" {
  length  = 16
  special = false # Avoid special chars to prevent JDBC URL encoding issues
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

# 2. Configure Private Service Access (Required for GKE -> Cloud SQL Private IP)
# NOTE: Ensure you reference your existing VPC network resource here
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address-${random_id.db_name_suffix.hex}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  project       = var.project_id  
  network       = google_compute_network.vpc.id 
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id 
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  deletion_policy         = "ABANDON"
}

# 3. The Cloud SQL Instance (High Availability)
resource "google_sql_database_instance" "artifactory_db" {
  name             = "artifactory-db-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_15"
  project       = var.project_id  
  region           = var.region 

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.db_tier
    availability_type = var.db_availability_type
    ip_configuration {
      ipv4_enabled    = false       # Disable Public IP for security
      private_network = google_compute_network.vpc.id 
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
    # to get rid of DB Sync error at 50% 
    database_flags {
      name  = "temp_file_limit"
      value = "2147483647"  # -1 does not work. 2147483647 (2TB) is the upper limit
    }
  }
  
  deletion_protection = false # Set to true for production to prevent accidental deletes
}

# 4. Create the Database and User
resource "google_sql_database" "database" {
  name     = "artifactory"
  project       = var.project_id  
  instance = google_sql_database_instance.artifactory_db.name
}

resource "google_sql_user" "users" {
  name     = "artifactory"
  project  = var.project_id  
  instance = google_sql_database_instance.artifactory_db.name
  password = random_password.db_password.result
  deletion_policy = "ABANDON"
}

# --- Xray Resources ---

resource "google_sql_database" "xray" {
  name     = "xraydb" # Standard name for Xray
  project  = var.project_id
  instance = google_sql_database_instance.artifactory_db.name
}

resource "google_sql_user" "xray" {
  name     = "xray"
  project  = var.project_id
  instance = google_sql_database_instance.artifactory_db.name
  password = random_password.db_password.result # We can share the same password for simplicity
  deletion_policy = "ABANDON"
}

