# ArgoCD Kubernetes GitOps

This repository manages cluster infrastructure and workloads, powered by **Argo CD** and **Helm**. It utilizes the **App-of-Apps pattern**.

## Repository Structure

```text
├── .github/
├── app-of-apps/                   # Root App-of-Apps patterns
│   ├── root-infra-app.yaml
│   └── root-workload-app.yaml
├── argocd/                        # Argo CD Application manifests
│   ├── applications/              # Application definitions for workloads
│   └── infra/                     # Infrastructure definitions/Cluster Level Tooling (Cert-Manager, Nginx, Prometheus, etc)
├── charts/
│    ├── applications/              # Custom Helm charts for applications/k8s manifests
│    │   └── app-example/
│    └── infra/                     # Overrides and values for infrastructure charts
│       ├── cert-manager/
│       └── external-secret/
├── cluster/                       # Terraform and cluster bootstrap configuration
│   ├── secret.auto.tfvars
│   ├── secret.auto.tfvars.example
│   ├── talos.tf
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   └── variable.auto.tfvars
├── components.yaml                # Metrics Server installation manifests
├── docker-compose.yaml            # Local development stack definition
├── readme.md
```

## Cluster Boostrap

1. Command:
   - terraform apply
   - terraform output -raw kubeconfig > ~/.kube/config
   - terraform output -raw talosconfig > ~/.talos/config

2. Deploy metrics server
   - kubectl apply -f components.yaml 

2. Install Argocd
   - kubectl create namespace argocd
   - kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

3. Apply the root applications to let ArgoCD manage the rest of the resources.

```bash
kubectl apply -f app-of-apps/root-infra-app.yaml
kubectl apply -f app-of-apps/root-workload-app.yaml
```

## Note:

- Using an ApplicationSet is a much better approach if you plan to manage more than one environment or deploy these tools across multiple clusters
