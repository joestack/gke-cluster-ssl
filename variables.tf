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

variable "cluster_instance" {
  description = "machine type to be used in the GKE cluster"
  default     = "e2-standard-4"
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

variable "db_tier" {
  description = "DB machine size"
  default     = "db-custom-4-16384"
}

variable "db_availability_type" {
  description = "REGIONAL for HA or ZONAL"
  default     = "ZONAL"
}

variable "catalog_enable" {
  description = "Enble JFrog Catalog/Curation feature"
  type = bool
  default = false
}

variable "distribution_enable" {
  description = "Enble JFrog Distribution feature"
  type = bool
  default = false
}

variable "runtime_enable" {
  description = "Enable generation of the JFrog Runtime Security values file"
  type        = bool
  default     = false  # Defaults to false to save resources on standard deployments
}

variable "worker_enable" {
  description = "Enable JFrog Worker"
  type        = bool
  default     = false  
}