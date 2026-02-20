# Generate 32 bytes and output as a 64-character hex string
resource "random_id" "master_key" {
  byte_length = 32
  # Terraform will never touch this again after the first apply.
  lifecycle {
    ignore_changes = all
  }
}

resource "random_id" "join_key" {
  byte_length = 32
  # Terraform will never touch this again after the first apply.
  lifecycle {
    ignore_changes = all
  }
}



resource "local_file" "jfrog_ingress_values" {
  filename = "${path.module}/generated/ingress-values.yaml"
  
  content = templatefile("${path.module}/templates/ingress-values.yaml.tftpl", {
    # Note: GCP DNS records often return with a trailing dot (e.g., "joe.rod.org.")
    # trimsuffix ensures Kubernetes doesn't throw a validation error on the Ingress host.
    hostname       = trimsuffix(google_dns_record_set.artifactory.name, ".")
    static_ip_name = google_compute_global_address.artifactory_ip.name
    ssl_cert_name  = google_compute_managed_ssl_certificate.artifactory.name
  })
}

# Generate the DB values file
resource "local_sensitive_file" "jfrog_db_values" {
  filename = "${path.module}/generated/db-values.yaml"
  
  content = templatefile("${path.module}/templates/db-values.yaml.tftpl", {
    db_ip            = google_sql_database_instance.artifactory_db.private_ip_address
    db_password      = random_password.db_password.result
    artifactory_db   = google_sql_database.database.name
    artifactory_user = google_sql_user.users.name
    xray_db          = google_sql_database.xray.name
    xray_user        = google_sql_user.xray.name
  })
}

# Generate the base values file
resource "local_sensitive_file" "jfrog_base_values" {
  filename = "${path.module}/generated/base-values.yaml"
  
  content = templatefile("${path.module}/templates/base-values.yaml.tftpl", {
    admin_password = var.jfrog_admin_password
    master_key     = random_id.master_key.hex
    join_key       = random_id.join_key.hex
    hostname       = "https://${trimsuffix(google_dns_record_set.artifactory.name, ".")}"
    gcs_bucket_name = google_storage_bucket.jfrog_filestore.name
    gcp_sa_email    = google_service_account.jfrog_gcs_sa.email
    replica_count   = var.replica_count
  })
}


locals {
  # If enabled, build the quoted string. If false, output the unquoted word "null".
  catalog_db_url           = var.catalog_enable ? "\"postgres://${google_sql_user.catalog_user[0].name}:${random_password.catalog_db_password[0].result}@${google_sql_database_instance.artifactory_db.private_ip_address}:5432/${google_sql_database.catalog_db[0].name}?sslmode=disable\"" : "null" 
  catalog_db_user          = var.catalog_enable ? "\"${google_sql_user.catalog_user[0].name}\"" : "null" 
  catalog_db_password      = var.catalog_enable ? "\"${random_password.catalog_db_password[0].result}\"" : "null"
  # Distribution uses Java/JDBC, so it needs a 'jdbc:postgresql://' format WITHOUT inline credentials
  distribution_db_url      = var.distribution_enable ? "\"jdbc:postgresql://${google_sql_database_instance.artifactory_db.private_ip_address}:5432/${google_sql_database.distribution_db[0].name}?sslmode=disable\"" : "null"
  distribution_db_user     = var.distribution_enable ? "\"${google_sql_user.distribution_user[0].name}\"" : "null"
  distribution_db_password = var.distribution_enable ? "\"${random_password.distribution_db_password[0].result}\"" : "null"
}




resource "local_file" "jfrog_xtra_values" {
  filename = "${path.module}/generated/xtra-values.yaml"
  
  content = templatefile("${path.module}/templates/xtra-values.yaml.tftpl", {
    # Note: GCP DNS records often return with a trailing dot (e.g., "joe.rod.org.")
    # trimsuffix ensures Kubernetes doesn't throw a validation error on the Ingress host.
    catalog_enabled       = var.catalog_enable
    catalog_db_url      = local.catalog_db_url
    catalog_db_user     = local.catalog_db_user
    catalog_db_password = local.catalog_db_password
    worker_enabled        = var.worker_enable 
    distribution_enabled  = var.distribution_enable
    distribution_db_url      = local.distribution_db_url
    distribution_db_user     = local.distribution_db_user
    distribution_db_password = local.distribution_db_password
  })
}

# Generate runtime values 
resource "local_sensitive_file" "jfrog_runtime_values" {
  # If true, create 1 file. If false, create 0 files.
  count    = var.runtime_enable ? 1 : 0

  filename = "${path.module}/generated/runtime-values.yaml"
  
  content = templatefile("${path.module}/templates/runtime-values.yaml.tftpl", {
    # Ensure these variable names match what you use in your other templates!
    dns_hostname = var.dns_hostname
    gcp_dns_zone = var.gcp_dns_zone
    join_key     = random_id.join_key.hex
    cluster_name = var.cluster_name
  })
}




