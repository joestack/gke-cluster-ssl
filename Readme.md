# 🐸 JFrog Platform on GKE with SSL, External Cloud SQL and External Storage Bucket

Welcome! This project provides a robust, fully automated Terraform setup to deploy the **JFrog Platform (Artifactory & Xray)** on Google Cloud Platform. 

Instead of dealing with manual secret generation or copy-pasting IP addresses, this project uses Terraform to provision the GCP infrastructure and **dynamically generate the Helm configuration files** needed to seamlessly connect the application to the cloud resources.

### ✨ Key Features
* **Google Kubernetes Engine (GKE):** Provisions the core cluster and networking.
* **External PostgreSQL (Cloud SQL):** Provisions a private Cloud SQL instance, creating dedicated databases and users for both Artifactory and Xray.
* **Dynamic Helm Values:** Automatically generates `base-values.yaml`, `db-values.yaml`, and `ingress-values.yaml` with injected database IPs, generated passwords, and Master/Join keys.

---

## ⚙️ Configuration (Variables)

Before applying the Terraform code, you need to define the required variables. The easiest way to do this is by creating a `terraform.tfvars` file in the root directory.

| NAME | DESCRIPTION | MANDATORY | DEFAULT |
| :--- | :--- | :---: | :--- |
| `project_id` | GCP Project ID | **Yes** | - |
| `gcp_dns_zone` | Cloud DNS Zone name where the record will be created (use `gcloud dns managed-zones list`) | **Yes** | - |
| `dns_hostname` | Hostname to be used for the A-Record (e.g., `artifactorytest`) | **Yes** | - |
| `jfrog_admin_password` | The initial admin password for Artifactory | **Yes** | - |
| `region` | GCP Region for the cluster and database | No | `"europe-west1"` |
| `zone` | GCP Zone for the GKE cluster | No | `"europe-west1-b"` |
| `cluster_name` | Name of the GKE Cluster | No | `"joern-gke-cluster"` |
| `cluster_instance` | Machine type to be used in the GKE cluster | No | `"e2-standard-4"` |
| `db_tier` | Cloud SQL machine size / instance tier | No | `"db-custom-4-16384"` |
| `db_availability_type` | Database availability (`REGIONAL` for HA or `ZONAL`) | No | `"ZONAL"` |
| `replica_count` | Number of RabbitMQ and Xray instances | No | `"1"` |
| `catalog_enable` | Enable JFrog Catalog/Curation feature | No | `false` |
| `distribution_enable` | Enable JFrog Distribution feature | No | `false` |
| `runtime_enable` | Enable generation of the JFrog Runtime Security values file | No | `false` |
| `worker_enable` | Enable JFrog Execution Worker (for Contextual Analysis) | No | `false` |
---

### 🛑 A Friendly Disclaimer: Walk Before You Run

The JFrog Platform Helm chart is an incredibly powerful and well-engineered tool, but it is also highly complex. Before you flip all the advanced feature toggles to `true`, **we highly recommend starting simple.**

Deploy the basic setup first using the default variable states. It is completely normal to need a few installation trials (and teardowns) to fully grasp how the persistence, databases, and microservices wire together. Get the core platform humming first, then introduce the advanced Enterprise+ features.

Finally, keep in mind that by deploying this architecture, you are standing up the heart of a Software Supply Chain (SSC). You are quite literally dealing with the "keys to the kingdom." Please be incredibly mindful of the following:

* **Your `art.lic` File:** This is your enterprise license. Never commit this to version control.
* **Your `terraform.tfstate` File:** By design, Terraform stores generated database passwords, root credentials, and your JFrog Join Key in *plain text* inside the state file. Ensure your state is stored securely (e.g., in a locked-down GCS backend) and never pushed to GitHub.
* **Cloud Credentials & Consumption:** Advanced features like Catalog and the Execution Workers require serious compute power to process vulnerability data. Keep a close eye on your GCP billing and GKE node scaling so you don't accidentally burn through your cloud budget!


### 🚀 Advanced Enterprise+ Features

This Terraform project natively supports deploying JFrog's advanced DevSecOps and Enterprise+ microservices. By default, these are set to `false` to save compute resources. 

You can enable them in your `terraform.tfvars` file.

* **`catalog_enable` (JFrog Catalog & Curation):** Deploys the central intelligence database for global packages and CVEs. This is required to power JFrog Curation, acting as a firewall to actively block malicious or highly vulnerable open-source packages from entering your proxy caches.
* **`worker_enable` (JFrog Execution Worker):** Enables the dedicated scanning engine for Contextual Analysis, Infrastructure as Code (IaC) scanning, and Secrets detection. It works by dynamically spinning up temporary Kubernetes Batch Jobs to perform deep scans on your containers.
* **`distribution_enable` (JFrog Distribution):** Spins up the Distribution microservice, allowing you to package immutable Release Bundles and distribute them securely to remote edge nodes. *(Note: Terraform automatically provisions the required dedicated Cloud SQL database for this when enabled).*
* **`runtime_enable` (JFrog Runtime Security):** Generates a dedicated `runtime-values.yaml` file and provides the exact Helm command needed to deploy Runtime K8s sensors. These lightweight DaemonSets monitor live cluster traffic and match running workloads against your Xray vulnerability database.

> **⚠️ Compute & License Warning:** > Enabling these features (especially Catalog and Worker) requires significant CPU and memory. If you set these to `true`, ensure your `cluster_instance` variable is set to a robust machine type (e.g., `e2-standard-8`) and your cluster can autoscale. These features also require an active **Enterprise X** or **Enterprise+** license.


## 🛠️ Prerequisites

Before you begin, ensure you have the following installed and configured:
* [Terraform](https://www.terraform.io/downloads)
* [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install) authenticated to your GCP project.
* [Kubernetes CLI (`kubectl`)](https://kubernetes.io/docs/tasks/tools/)
* [Helm](https://helm.sh/docs/intro/install/)
* A valid JFrog Artifactory license file named `art.lic` located in the root of this repository.
* optional but highly recommended [k9s](https://github.com/derailed/k9s) -- many thanks to Tom for this tip!
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
  -f generated/db-values.yaml \
  -f generated/xtra-values.yaml
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