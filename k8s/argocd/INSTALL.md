# ArgoCD Installation

ArgoCD is installed once after `terraform apply` brings the EKS cluster up.

## Step 1 — Install ArgoCD

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Step 2 — Wait for ArgoCD to be ready

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

## Step 3 — Apply the Application CRD

```bash
kubectl apply -f k8s/argocd/application.yaml
```

ArgoCD will now watch the `k8s/` folder on the `devops` branch and auto-sync to EKS.

## Step 4 — Get the initial admin password

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

## Step 5 — Access the ArgoCD UI (port-forward)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open: https://localhost:8080
Username: `admin`
Password: from Step 4
