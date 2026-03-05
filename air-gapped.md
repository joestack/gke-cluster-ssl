# JFrog Platform on GKE via Corporate Proxy

This repository contains the Terraform and Helm configurations to deploy the JFrog Platform on a dedicated Google Kubernetes Engine (GKE) cluster. 

To avoid Docker Hub rate limits and ensure an enterprise-grade, secure deployment, this setup routes **all** Helm chart and Docker image pulls through a central corporate Artifactory instance acting as a proxy.

## 📋 Prerequisites
* `gcloud` CLI authenticated to your GCP project.
* `kubectl` authenticated to your GKE cluster.
* `helm` CLI installed (v3+).
* Access to the central corporate Artifactory UI (e.g., `solengeu.jfrog.io`) to generate an Access Token.

---

## Phase 1: Configure the Corporate Proxy (Artifactory UI)

Before deploying, ensure the central Artifactory has the following **Remote Repositories** configured:

1. **Remote Helm Repository**
   * **Package Type:** Helm
   * **Repository Key:** `joe-jfrog-helm-remote`
   * **URL:** `https://charts.jfrog.io`
2. **Remote Docker Repository (JFrog Official Images)**
   * **Package Type:** Docker
   * **Repository Key:** `joe-jfrog-docker-remote`
   * **URL:** `https://releases-docker.jfrog.io`
3. **Remote Docker Repository (Bitnami Dependencies)**
   * **Package Type:** Docker
   * **Repository Key:** `joe-docker-hub-remote`
   * **URL:** `https://registry-1.docker.io`

### 🔑 Generate your Credentials
1. Go to your JFrog Profile -> **Generate Token**.


---

## Phase 2: Prepare the Target Cluster

The GKE cluster needs permission to pull Docker images from the corporate proxy. Create a Kubernetes secret in the target namespace.

*⚠️ **Warning:** Do not include `https://` or repository paths in the `--docker-server` flag!*

```bash
kubectl create namespace jfrog-platform

kubectl create secret docker-registry proxy-artifactory-secret \
  --docker-server=solengeu.jfrog.io \
  --docker-username=<YOUR_SHORT_USERNAME> \
  --docker-password=<YOUR_ACCESS_TOKEN> \
  --docker-email=<YOUR_EMAIL> \
  -n jfrog-platform
```

---

## Phase 3: Helm Values Configuration (`values.yaml`)

We must override the default image registries in the Helm chart to point to our proxy. 

*⚠️ **Warning:** Kubernetes will throw an `Init:InvalidImageName` error if you include `https://` or a trailing slash `/` in these registry strings.*

```yaml
global:
  # Route JFrog images through proxy (No https://, no trailing /)
  imageRegistry: "solengeu.jfrog.io/joe-jfrog-docker-remote"
  
  # Attach the secret we created in Phase 2
  imagePullSecrets:
    - proxy-artifactory-secret

  # (Optional) Pin specific application versions
  versions:
    artifactory: "7.77.5"
    xray: "3.82.7"

# Route Bitnami database images through Docker Hub proxy
postgresql:
  image:
    registry: "solengeu.jfrog.io/joe-docker-hub-remote"
redis:
  image:
    registry: "solengeu.jfrog.io/joe-docker-hub-remote"
```
*(Note: In this project, these values are dynamically generated via Terraform templates).*

---

## Phase 4: Execute the Deployment

Configure your local Helm CLI to pull the installation charts from the proxy, then execute the deployment.

**1. Add the Proxy Repository:**
*(Use your short username, e.g., `joerns`, and your Access Token).*
```bash
helm repo add my-jfrog-proxy https://solengeu.jfrog.io/artifactory/joe-jfrog-helm-remote/ \
  --username <YOUR_SHORT_USERNAME> \
  --password <YOUR_ACCESS_TOKEN>
```

**2. Update the local index:**
```bash
helm repo update my-jfrog-proxy
```

**3. Install the Chart:**
```bash
helm upgrade --install jfrog-platform my-jfrog-proxy/jfrog-platform \
  --version 11.4.3 \
  --namespace jfrog-platform \
  -f generated/base-values.yaml \
  -f generated/db-values.yaml
```

---

## 🛠️ Troubleshooting & Known Gotchas

* **Pods stuck in `Init:InvalidImageName`:** Double-check your `values.yaml`. You likely left `https://` or a trailing `/` in your `imageRegistry` string.
* **`401 Unauthorized` during `helm repo add`:** Ensure you are using an **Access Token** (not a Refresh Token) and try dropping the domain from your username (e.g., use `joerns` instead of `joerns@jfrog.com`).
* **`404 Not Found` during `helm repo add`:** Ensure the remote repository in Artifactory is explicitly set to the **Helm** package type, not Generic or Docker.
* **Terraform stuck destroying `google_compute_managed_ssl_certificate`:** If tearing down the environment, GKE Ingress controllers often leave orphaned `TargetHttpsProxies` in GCP that hold SSL certificates hostage. You must manually delete the proxy in the GCP Console (or via `gcloud compute target-https-proxies delete ...`) before Terraform can destroy the cert.