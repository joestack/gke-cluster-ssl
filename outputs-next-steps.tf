output "next_steps" {
  description = "Instructions and prerequisites to run before deploying the JFrog Helm chart."
  value = <<EOT

====================================================================
🚀 PREREQUISITES & NEXT STEPS FOR JFROG HELM DEPLOYMENT
====================================================================

Because Terraform is now managing your Master Key and Join Key securely 
in the state file and injecting them into your base-values.yaml, your 
deployment process is significantly simpler!

Execute the following commands in your terminal:

# 1. Authenticate to the GKE Cluster
gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}

# 2. Create the target namespace
kubectl create namespace jfrog-platform

# 3. Apply the GKE FrontendConfig (required for the GCE Ingress)
kubectl apply -f frontend-config.yaml

# 4. Create the License secret
# NOTE: Ensure your 'art.lic' file is located in your current working directory!
kubectl create secret generic artifactory-cluster-license --from-file=./art.lic -n jfrog-platform

# 5. Deploy the JFrog Platform via Helm
# This automatically applies your Terraform-generated configurations, 
# including the Master/Join keys, Admin password, and Database settings!
helm upgrade --install jfrog-platform jfrog/jfrog-platform \
  --namespace jfrog-platform \
  -f generated/base-values.yaml \
  -f generated/ingress-values.yaml \
  -f generated/db-values.yaml \
  -f generated/xtra-values.yaml

# n. Delete the helm chart
helm uninstall jfrog-platform -n jfrog-platform


====================================================================
Your deployment will begin! You can monitor the pods using:
kubectl get pods -n jfrog-platform -w

wait..
     listen to Tom Paz -- thanks mate
        and get familiar with "k9s" 
====================================================================
EOT
}