# PulseLog — DevSecOps Project

A full-stack developer blog platform built to learn and demonstrate end-to-end DevSecOps practices on AWS.

## Stack

- **Frontend** — React 18 + Vite + Nginx
- **Backend** — Node.js + Express
- **Database** — PostgreSQL 16
- **Infra** — AWS EKS (Terraform)
- **CI** — GitHub Actions
- **CD** — ArgoCD
- **Security** — Trivy, Checkov, Hadolint, ESLint, npm audit
- **Secrets** — HashiCorp Vault
- **Policy** — Kyverno
- **Packaging** — Helm + Kustomize
- **Registry** — AWS ECR

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Application source code (frontend, backend, database) |
| `devops` | Infrastructure, CI/CD, Helm charts, Terraform, ArgoCD |
