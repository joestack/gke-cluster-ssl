# 1. Create the GCS Bucket
resource "google_storage_bucket" "jfrog_filestore" {
  name                        = "${var.project_id}-jfrog-filestore"
  location                    = var.region
  force_destroy               = true # Safe for testing/teardowns
  uniform_bucket_level_access = true
  project = var.project_id
}

# 2. Create the GCP Service Account
resource "google_service_account" "jfrog_gcs_sa" {
  account_id   = "jfrog-gcs-sa"
  display_name = "JFrog GCS Access"
  project = var.project_id
}

# 3. Grant the GCP SA permission to write to the bucket
resource "google_storage_bucket_iam_member" "jfrog_gcs_admin" {
  bucket = google_storage_bucket.jfrog_filestore.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.jfrog_gcs_sa.email}"
}

# 4. Link the K8s Service Account to the GCP Service Account (Workload Identity)
# Note: "jfrog-platform" is your K8s namespace, and "jfrog-platform-artifactory" is the default K8s SA name created by Helm.
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.jfrog_gcs_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[jfrog-platform/jfrog-platform-artifactory]"
  ]
}