# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "joern-gke-cluster"
}

variable "gcp_dns_zone" {
  description = "DNS Zone"
}

variable "dns_hostname" {
  description = "Hostname to be used for the A-Record (i.eg. artifactorytest)"
}

variable "jfrog_admin_password" {
  description = "The initial admin password for Artifactory"
  type        = string
  sensitive   = true
}