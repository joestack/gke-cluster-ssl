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
  project       = var.project_id  # <--- ADD THIS LINE
  network       = google_compute_network.vpc.id # <--- UPDATE THIS if your network resource is named differently
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id # <--- UPDATE THIS
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  # ADD THIS LINE so terraform destroy doesn't fail next time
  deletion_policy = "ABANDON"
}

# 3. The Cloud SQL Instance (High Availability)
resource "google_sql_database_instance" "artifactory_db" {
  name             = "artifactory-db-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_15"
  project       = var.project_id  # <--- ADD THIS LINE
  region           = var.region # Ensure var.region is defined in your variables

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-custom-2-7680" # Adjust size as needed
    #availability_type = "REGIONAL"         # <--- Enables High Availability
    availability_type = "ZONAL"         # <--- Disables High Availability

    ip_configuration {
      ipv4_enabled    = false       # Disable Public IP for security
      private_network = google_compute_network.vpc.id # <--- UPDATE THIS
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }
  
  deletion_protection = false # Set to true for production to prevent accidental deletes
}

# 4. Create the Database and User
resource "google_sql_database" "database" {
  name     = "artifactory"
  project       = var.project_id  # <--- ADD THIS LINE
  instance = google_sql_database_instance.artifactory_db.name
}

resource "google_sql_user" "users" {
  name     = "artifactory"
  project       = var.project_id  # <--- ADD THIS LINE
  instance = google_sql_database_instance.artifactory_db.name
  password = random_password.db_password.result
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
}

# 5. Output the Credentials
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