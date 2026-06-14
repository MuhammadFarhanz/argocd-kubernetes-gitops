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
    ├── applications/              # Custom Helm charts for applications/k8s manifests
    │   └── app-example/
    └── infra/                     # Overrides and values for infrastructure charts
        ├── cert-manager/
        └── external-secret/
```

## Bootstrap

Apply the root applications to let ArgoCD manage the rest of the resources.

```bash
kubectl apply -f app-of-apps/root-infra-app.yaml
kubectl apply -f app-of-apps/root-workload-app.yaml
```

## Note:
- Using an ApplicationSet is a much better approach if you plan to manage more than one environment or deploy these tools across multiple clusters
