# 🐸 JFrog Platform on GKE with SSL, External Cloud SQL and External Storage Bucket

Welcome! This project provides a robust, fully automated Terraform setup to deploy the **JFrog Platform (Artifactory & Xray)** on Google Cloud Platform. 

Instead of dealing with manual secret generation or copy-pasting IP addresses, this project uses Terraform to provision the GCP infrastructure and **dynamically generate the Helm configuration files** needed to seamlessly connect the application to the cloud resources.

### ✨ Key Features
* **Google Kubernetes Engine (GKE):** Provisions the core cluster and networking.
* **External PostgreSQL (Cloud SQL):** Securely provisions a private Cloud SQL instance, creating dedicated databases and users for both Artifactory and Xray.
* **Dynamic Helm Values:** Automatically generates `base-values.yaml`, `db-values.yaml`, and `ingress-values.yaml` with injected database IPs, generated passwords, and perfectly formatted 64-character Hex Master/Join keys.
* **Production-Ready Tweaks:** Includes fixes for GKE Go-cache permission drops and internal Kubernetes DNS routing.

---

## ⚙️ Configuration (Variables)

Before applying the Terraform code, you need to define the required variables. The easiest way to do this is by creating a `terraform.tfvars` file in the root directory.

| NAME | DESCRIPTION | MANDATORY | DEFAULT |
| :--- | :--- | :---: | :--- |
| `project_id` | GCP Project ID | **Yes** | - |
| `gcp_dns_zone` | Cloud DNS Zone name where the record will be created | **Yes** | - |
| `dns_hostname` | Hostname to be used for the A-Record (e.g., `artifactorytest`) | **Yes** | - |
| `jfrog_admin_password` | The initial admin password for Artifactory | **Yes** | - |
| `region` | GCP Region for the cluster and database | No | `"europe-west1"` |
| `zone` | GCP Zone for the GKE cluster | No | `"europe-west1-b"` |
| `cluster_name` | Name of the GKE Cluster | No | `"joern-gke-cluster"` |
| `db_tier` | Cloud SQL machine size / instance tier | No | `"db-custom-4-16384"` |
| `db_availability_type` | Database availability (`REGIONAL` for HA or `ZONAL`) | No | `"ZONAL"` |

---

## 🛠️ Prerequisites

Before you begin, ensure you have the following installed and configured:
* [Terraform](https://www.terraform.io/downloads)
* [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install) authenticated to your GCP project.
* [Kubernetes CLI (`kubectl`)](https://kubernetes.io/docs/tasks/tools/)
* [Helm](https://helm.sh/docs/intro/install/)
* A valid JFrog Artifactory license file named `art.lic` located in the root of this repository.

---

## 🚀 Deployment Guide

### 1. Provision the Infrastructure
Initialize and apply the Terraform configuration. This will spin up the GKE cluster, Cloud SQL database, network peering, and generate the Helm values files in the `generated/` directory.

```bash
terraform init
terraform apply
```

### 2. Configure Kubernetes
Once Terraform completes, it will output a set of instructions. Run the following commands to authenticate your local terminal to the new GKE cluster and prepare the environment:

```bash
# Authenticate to the cluster (replace with your actual output values)
gcloud container clusters get-credentials <your-cluster-name> --zone <your-zone> --project <your-project-id>

# Create the namespace
kubectl create namespace jfrog-platform

# Apply the GKE FrontendConfig (required for GCP Ingress SSL/Routing)
kubectl apply -f frontend-config.yaml
```

### 3. Apply the JFrog License
Create a Kubernetes secret containing your Artifactory license so the application can boot successfully:

```bash
kubectl create secret generic artifactory-cluster-license \
  --from-file=./art.lic \
  -n jfrog-platform
```

### 4. Deploy the Helm Chart
Deploy the JFrog Platform using the official Helm chart, passing in the configuration files that Terraform dynamically generated for you:

```bash
helm repo add jfrog https://charts.jfrog.io
helm repo update

helm upgrade --install jfrog-platform jfrog/jfrog-platform \
  --namespace jfrog-platform \
  -f generated/base-values.yaml \
  -f generated/ingress-values.yaml \
  -f generated/db-values.yaml
```

You can monitor the deployment progress by watching the pods:
```bash
kubectl get pods -n jfrog-platform -w
```

---

## 🧹 Cleanup and Teardown

To completely destroy the environment and avoid incurring further cloud costs, simply run:

```bash
terraform destroy
```
*Note: The Terraform state is configured to gracefully drop the PostgreSQL databases before deleting the users, and to abandon the VPC peering connection to prevent GCP backend deletion timeouts.*