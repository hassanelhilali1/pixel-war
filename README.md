# Pixel War 2026 — ISIMA DevOps


![CI/CD](https://img.shields.io/github/actions/workflow/status/hassanelhilali1/pixel-war/ci-cd.yml?branch=main&label=CI%2FCD)
![Kubernetes](https://img.shields.io/badge/kubernetes-1.28-blue)
![Helm](https://img.shields.io/badge/helm-3.13-informational)

---

## Table des matières

1. [Architecture](#architecture)
2. [Stack technique](#stack-technique)
3. [Structure du projet](#structure-du-projet)
4. [Déploiement rapide (script automatisé)](#deploiement-rapide)
5. [Déploiement manuel pas à pas](#deploiement-manuel)
6. [CI/CD](#cicd)
7. [Sécurité](#securite)
8. [Observabilité](#observabilite)
9. [Résilience](#resilience)

---

## Architecture

```
Navigateur
    |
    v
Ingress Nginx (pixel-war.local)
    |
    +---> Frontend  (React + Vite, servi par Nginx)
              |
              v
          Backend  (Node.js + Express + socket.io)
              |
              +---> PostgreSQL  (StatefulSet, PVC persistant)
              |
              +---> /metrics  <--- Prometheus  <--- Grafana
```

Tous les composants tournent dans le namespace `pixel-war` sur un cluster Minikube.  
Les flux réseau sont contrôlés par des **NetworkPolicies** strictes (frontend → backend → PostgreSQL uniquement).

---

## Stack technique

| Couche | Technologie |
|---|---|
| Frontend | React 18 + Vite + socket.io-client, servi par Nginx |
| Backend | Node.js 20 + Express + socket.io + prom-client |
| Base de données | PostgreSQL 16 (StatefulSet natif Kubernetes) |
| Conteneurisation | Docker multi-stage (image non-root, readOnlyRootFilesystem) |
| Orchestration | Kubernetes 1.28 via Minikube |
| Package K8s | Helm 3 (chart custom `k8s/charts/pixel-war`) |
| IaC | Terraform >= 1.6 (namespace, secrets, PostgreSQL, quotas) |
| Configuration | Ansible (Docker, kubectl, Helm, Minikube, Terraform) |
| CI/CD | GitHub Actions (lint → tests → security → build → deploy) |
| Observabilité | Prometheus + Grafana (kube-prometheus-stack) |

---

## Structure du projet

```
pixel-war/
├── app/
│   ├── backend/                  # Node.js + Express + socket.io
│   │   ├── src/
│   │   │   ├── index.js          # Point d'entrée, middlewares, WebSocket
│   │   │   ├── metrics.js        # Métriques Prometheus custom
│   │   │   ├── routes/           # health.js, grid.js
│   │   │   └── db/               # pool.js, migrate.js
│   │   └── Dockerfile            # Multi-stage, non-root (uid 1001)
│   └── frontend/                 # React + Vite
│       ├── src/
│       │   ├── App.jsx           # Grille, WebSocket, état global
│       │   └── components/       # Grid.jsx, ColorPicker.jsx
│       └── Dockerfile            # Multi-stage, build statique + Nginx
├── infra/
│   ├── terraform/                # Provisioning K8s (namespace, secrets, PG)
│   └── ansible/                  # Rôles : docker, kubernetes_tools, minikube, terraform
├── k8s/
│   ├── charts/pixel-war/         # Helm chart (deployment, service, ingress, HPA, PDB, NetworkPolicy)
│   └── monitoring/               # values kube-prometheus-stack
├── .github/workflows/
│   └── ci-cd.yml                 # Pipeline complet
├── deploy.sh                     # Script de déploiement automatisé (Mode 2)
└── docker-compose.yml            # Dev local (Mode 1)
```

---

## Deploiement rapide

### Mode 1 — Docker Compose (dev local)

```bash
git clone https://github.com/hassanelhilali1/pixel-war
cd pixel-war
docker compose up --build
```

| Service | URL |
|---|---|
| Application | http://localhost |
| API health | http://localhost:3000/api/health |
| Métriques | http://localhost:3000/metrics |

```bash
docker compose down          # arrêter
docker compose down -v       # arrêter + supprimer les volumes
```

---

### Mode 2 — Kubernetes / Minikube (script automatisé)

Un seul script prend en charge l'intégralité du déploiement :

```bash
# Déploiement complet
./deploy.sh

# Avec Prometheus + Grafana
./deploy.sh --monitoring

# Tout supprimer
./deploy.sh --destroy
```

Le script effectue dans l'ordre :
1. Vérifie les prérequis (`docker`, `minikube`, `kubectl`, `helm`, `terraform`)
2. Démarre Minikube + active les addons `ingress` et `metrics-server`
3. Build les images dans l'environnement Docker de Minikube (`pullPolicy: Never`)
4. `terraform init` + `terraform apply`
5. `helm upgrade --install` avec `--atomic`
6. Ajoute les entrées DNS dans `/etc/hosts`
7. Lance `minikube tunnel` en arrière-plan

**Prérequis :** avoir au préalable configuré la machine hôte une seule fois via Ansible :

```bash
cd infra/ansible
ansible-playbook -i inventory/localhost.yml playbook.yml --ask-become-pass```

---

## Deploiement manuel

> Suivre ces étapes si vous ne souhaitez pas utiliser `deploy.sh`.

### Étape 1 — Configurer la machine hôte (Ansible)

> A faire **une seule fois** sur une nouvelle machine.

```bash
cd infra/ansible
ansible-playbook -i inventory/localhost.yml playbook.yml --ask-become-pass```

Installe : Docker, kubectl, Helm, Minikube, Terraform.

Tags disponibles pour n'installer qu'un outil :

```bash
ansible-playbook -i inventory/localhost.yml playbook.yml --tags docker
ansible-playbook -i inventory/localhost.yml playbook.yml --tags minikube
ansible-playbook -i inventory/localhost.yml playbook.yml --tags terraform
```

---

### Étape 2 — Démarrer Minikube

```bash
minikube start --cpus=4 --memory=6g --driver=docker
minikube addons enable ingress
minikube addons enable metrics-server
kubectl get nodes
```

---

### Étape 3 — Builder les images dans Minikube

```bash
eval $(minikube docker-env)
docker build -t pixel-war-backend:latest  ./app/backend  --target production
docker build -t pixel-war-frontend:latest ./app/frontend --target production --build-arg VITE_GRID_SIZE=50
```

> Les images utilisent `pullPolicy: Never` — elles doivent obligatoirement être buildées dans l'environnement Docker de Minikube.

---

### Étape 4 — Provisionner l'infrastructure (Terraform)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Editer terraform.tfvars : renseigner db_password (12 caractères min)

terraform init
terraform plan
terraform apply
```

Ressources créées : namespace `pixel-war`, ResourceQuota, LimitRange, Secret `db-credentials`, ConfigMap `app-config`, StatefulSet PostgreSQL.

---

### Étape 5 — Déployer l'application (Helm)

```bash
cd ../..   # retour à la racine

helm upgrade --install pixel-war k8s/charts/pixel-war/ \
  --namespace pixel-war \
  --values k8s/charts/pixel-war/values.yaml \
  --wait --atomic --timeout 5m

kubectl get pods    -n pixel-war
kubectl get ingress -n pixel-war
```

---

### Étape 6 — DNS local + tunnel

```bash
# Ajouter l'entrée DNS
echo "$(minikube ip)  pixel-war.local" | sudo tee -a /etc/hosts

# Exposer l'Ingress (laisser tourner dans un terminal dédié)
minikube tunnel
```

---

### Étape 7 —  Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values k8s/monitoring/values.yaml \
  --wait --timeout 10m

echo "$(minikube ip)  grafana.local prometheus.local" | sudo tee -a /etc/hosts
```

---

### Accès aux services

| Service | URL | Identifiants |
|---|---|---|
| Application | http://pixel-war.local | — |
| API health | http://pixel-war.local/api/health | — |
| Grafana | http://grafana.local | admin / prom-operator |
| Prometheus | http://prometheus.local | — |

---

### Commandes utiles

```bash
# Etat complet du namespace
kubectl get all -n pixel-war

# Logs en direct
kubectl logs -n pixel-war -l app.kubernetes.io/component=backend  -f
kubectl logs -n pixel-war -l app.kubernetes.io/component=frontend -f

# Autoscaling
kubectl get hpa -n pixel-war

# Rollback Helm
helm rollback pixel-war -n pixel-war

# Supprimer le déploiement
helm uninstall pixel-war    -n pixel-war
helm uninstall monitoring   -n monitoring
cd infra/terraform && terraform destroy

# Arrêter / supprimer Minikube
minikube stop
minikube delete
```

---

## CICD

Le pipeline GitHub Actions se déclenche automatiquement :

| Déclencheur | Jobs exécutés |
|---|---|
| `pull_request → main` | Lint (ESLint + hadolint + yamllint) + Tests |
| `push → main` | Lint → Tests → Security scan → Build & Push → Deploy staging → Smoke test |
| `tag v*.*.*` | Idem + Deploy production + GitHub Release |

**Jobs détaillés :**

- **Lint** — ESLint (backend + frontend), hadolint (Dockerfiles), yamllint (YAML/K8s)
- **Tests** — Jest + coverage (seuil : 90% branches sur `src/routes/`)
- **Security** — Checkov (Terraform + manifests K8s), Trivy (images Docker)
- **Build** — Docker Buildx multi-platform, push vers GHCR avec cache GitHub Actions
- **Deploy** — `helm upgrade --install --atomic`, smoke test sur `/api/health` et `/api/grid`

**Secret GitHub requis :**

| Secret | Description |
|---|---|
| `KUBECONFIG` | Contenu de `~/.kube/config` encodé en base64 |

```bash
# Générer la valeur du secret
cat ~/.kube/config | base64 -w 0
```

---

## Securite

| Mesure | Détail |
|---|---|
| Conteneurs non-root | `runAsUser: 1001`, `runAsNonRoot: true` |
| Filesystem en lecture seule | `readOnlyRootFilesystem: true` |
| Pas d'escalade de privilèges | `allowPrivilegeEscalation: false` |
| Capabilities supprimées | `capabilities: drop: [ALL]` |
| NetworkPolicy | Frontend → Backend → PostgreSQL uniquement (flux interdits par défaut) |
| Secrets | Créés par Terraform, jamais commités dans le dépôt |
| Scan CI | Trivy (images) + Checkov (IaC) à chaque push |
| `terraform.tfvars` | Dans `.gitignore`, jamais versionné |

---

## Observabilite

### Métriques Prometheus custom

| Métrique | Type | Description |
|---|---|---|
| `pixels_placed_total` | Counter | Nombre de pixels posés, labelisé par `color` |
| `ws_connections_active` | Gauge | Connexions WebSocket actives en temps réel |
| `api_request_duration_seconds` | Histogram | Latence des requêtes HTTP par route et code HTTP |
| `db_query_duration_seconds` | Histogram | Latence des requêtes PostgreSQL par opération |

### Dashboard Grafana

Un dashboard **"Pixel War — Application"** est automatiquement provisionné avec 4 panneaux :
- Pixels posés / seconde (`rate`)
- Connexions WebSocket actives
- Latence API p99
- Taux d'erreurs 5xx

Accès : http://grafana.local — `admin` / `prom-operator`

---

## Resilience

| Mécanisme | Configuration |
|---|---|
| Réplicas minimum | 2 (frontend + backend) |
| HPA backend | 2 → 5 réplicas si CPU > 70% |
| PodDisruptionBudget | `minAvailable: 1` (aucune interruption totale) |
| Rolling update | `maxUnavailable: 0`, `maxSurge: 1` (zéro downtime) |
| Rollback automatique | `helm upgrade --atomic` (rollback si deploy échoue) |
| Probes | Readiness + Liveness sur `/api/health` |
| Persistance DB | PVC `hostPath` — les données survivent aux redémarrages |

---
