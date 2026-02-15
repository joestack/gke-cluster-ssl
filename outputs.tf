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

output "load_balancer_ip_name" {
  description = "Load balancer IP address"
  value       = google_compute_global_address.artifactory_ip.name
  }

# Output DB Credentials
output "db_instance_connection_name" {
  value = google_sql_database_instance.artifactory_db.connection_name
}

output "db_private_ip" {
  value = google_sql_database_instance.artifactory_db.private_ip_address
}

output "db_user" {
  value = google_sql_user.users.name
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "db_name" {
  value = google_sql_database.database.name
}

output "jdbc_url" {
  description = "JDBC URL for Artifactory configuration"
  value       = "jdbc:postgresql://${google_sql_database_instance.artifactory_db.private_ip_address}:5432/${google_sql_database.database.name}"
  sensitive   = true
}