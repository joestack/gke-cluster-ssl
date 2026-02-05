# Outputs
output "cluster_name" {
  description = "GKE Cluster Name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "ingress_ip" {
  description = "Static IP for Ingress"
  value       = google_compute_global_address.artifactory_ip.address
}

output "ssl_certificate_name" {
  description = "SSL certificate name for GKE Ingress"
  value       = google_compute_managed_ssl_certificate.artifactory.name
}

output "dns_name" {
  description = "DNS name for the service"
  value       = google_dns_record_set.artifactory.name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = google_compute_global_address.artifactory_ip.address
  }
