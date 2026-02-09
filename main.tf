terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
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

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
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
  #name    = "rodolphef-org" 
  name    = var.gcp_dns_zone 

  project = var.project_id
}

resource "google_compute_global_address" "artifactory_ip" {
  name    = "artifactory-ingress-ip"
  project = var.project_id
}

resource "google_dns_record_set" "artifactory" {
  #name         = "joe.${data.google_dns_managed_zone.artifactorytest.dns_name}"
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
    #domains = ["joe.${data.google_dns_managed_zone.artifactorytest.dns_name}"]
    domains = ["${var.dns_hostname}.${data.google_dns_managed_zone.artifactorytest.dns_name}"]

  }
}

