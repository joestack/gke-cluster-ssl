# DNS Zone (reference existing zone)
data "google_dns_managed_zone" "artifactorytest" {
  #name    = "artifactorytest"
  name    = "rodolphef-org" 
  project = var.project_id
}

# # Reserve a global static IP address for the HTTPS load balancer
# resource "google_compute_global_address" "lb_ip" {
#   name    = "${var.cluster_name}-lb-ip"
#   project = var.project_id
# }

# Statische IP für den Ingress reservieren
resource "google_compute_global_address" "artifactory_ip" {
  name    = "artifactory-ingress-ip"
  project = var.project_id
}


# # Create DNS A record
# resource "google_dns_record_set" "joe_a_record" {
#   name         = "joe.jfrogrt.net."
#   type         = "A"
#   ttl          = 300
#   managed_zone = data.google_dns_managed_zone.artifactorytest.name
#   project      = var.project_id

#   rrdatas = [google_compute_global_address.ingress_ip.address]
# }

# DNS A-Record erstellen
resource "google_dns_record_set" "artifactory" {
  name         = "joe.${data.google_dns_managed_zone.artifactorytest.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.artifactorytest.name
  project      = var.project_id
  
  rrdatas = [google_compute_global_address.artifactory_ip.address]
}

# Google-managed SSL Zertifikat
resource "google_compute_managed_ssl_certificate" "artifactory" {
  name    = "artifactory-ssl-cert"
  project = var.project_id
  
  managed {
    domains = ["joe.${data.google_dns_managed_zone.artifactorytest.dns_name}"]
  }
}