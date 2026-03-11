# 🎨 Pixel War 2026 — ISIMA DevOps

> Application collaborative de pixels en temps réel (inspirée de r/place), déployée sur une stack Cloud-Native complète.

![CI/CD](https://img.shields.io/github/actions/workflow/status/YOUR_ORG/pixel-war/ci-cd.yml?branch=main&label=CI%2FCD)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 📐 Architecture

```
Navigateur → Ingress Nginx → Frontend (React/Nginx) → Backend (Node.js/socket.io) → PostgreSQL
                                                   ↓
                                           Prometheus /metrics
                                                   ↓
                                              Grafana
```

**Stack :** React + Vite • Node.js + Express + socket.io • PostgreSQL • Minikube • Terraform • Ansible • Helm • GitHub Actions • Prometheus/Grafana

---

## 📁 Structure du projet

```
pixel-war/
├── app/
│   ├── frontend/          # React + Vite + Nginx
│   └── backend/           # Node.js + Express + socket.io
├── infra/
│   ├── terraform/         # Provisioning K8s (namespace, secrets, PostgreSQL)
│   └── ansible/           # Configuration machine hôte
├── k8s/
│   ├── charts/pixel-war/  # Helm chart custom
│   └── monitoring/        # kube-prometheus-stack values
├── .github/workflows/     # Pipeline CI/CD
└── docker-compose.yml     # Dev local
```

---

## 🚀 Démarrage rapide

### Mode 1 — Développement local (Docker Compose)

```bash
git clone https://github.com/YOUR_ORG/pixel-war
cd pixel-war
docker compose up --build
```

| Service     | URL                              |
|-------------|----------------------------------|
| Application | http://localhost                 |
| API health  | http://localhost:3000/api/health |
| Métriques   | http://localhost:3000/metrics    |

Pour arrêter :

```bash
docker compose down
```

---

### Mode 2 — Cluster Kubernetes (Minikube)

> Exécuter les étapes **dans l'ordre**.

---

#### Étape 1 — Configurer la machine hôte (Ansible)

> À ne faire **qu'une seule fois** sur une nouvelle machine.

```bash
cd infra/ansible
ansible-playbook -i inventory/localhost.yml playbook.yml
```

Installe : Docker, kubectl, Helm, Minikube, Terraform.

Tags disponibles pour n'exécuter qu'une partie :

```bash
ansible-playbook -i inventory/localhost.yml playbook.yml --tags docker
ansible-playbook -i inventory/localhost.yml playbook.yml --tags minikube
ansible-playbook -i inventory/localhost.yml playbook.yml --tags terraform
```

---

#### Étape 2 — Démarrer Minikube

```bash
minikube start --cpus=4 --memory=6g --driver=docker
```

Activer les addons nécessaires :

```bash
minikube addons enable ingress
minikube addons enable metrics-server
```

*(Optionnel)* Ajouter des nœuds workers :

```bash
minikube node add --worker   # 1er worker
minikube node add --worker   # 2e worker
```

Vérifier l'état du cluster :

```bash
kubectl get nodes
```

---

#### Étape 3 — Builder les images dans Minikube

> Les images sont utilisées avec `pullPolicy: Never` — elles doivent être buildées **dans l'environnement Docker de Minikube**.

```bash
eval $(minikube docker-env)

docker build -t pixel-war-backend:latest ./app/backend --target production
docker build -t pixel-war-frontend:latest ./app/frontend --target production --build-arg VITE_GRID_SIZE=50
```

---

#### Étape 4 — Provisionner l'infrastructure (Terraform)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# ✏️  Éditer terraform.tfvars et renseigner db_password
```

```bash
terraform init
terraform plan
terraform apply
```

Crée : namespace `pixel-war`, ResourceQuota, LimitRange, Secret DB, ConfigMap, PostgreSQL (via Helm Bitnami).

---

#### Étape 5 — Déployer l'application (Helm)

```bash
cd ../../   # retour à la racine du projet

helm upgrade --install pixel-war k8s/charts/pixel-war/ \
  --namespace pixel-war \
  --values k8s/charts/pixel-war/values.yaml
```

Vérifier que tout est Running :

```bash
kubectl get pods -n pixel-war
kubectl get ingress -n pixel-war
```

---

#### Étape 6 — Ajouter l'entrée DNS locale

```bash
echo "$(minikube ip)  pixel-war.local" | sudo tee -a /etc/hosts
```

---

#### Étape 7 — Exposer l'Ingress (tunnel)

> Laisser cette commande tourner dans un **terminal dédié**.

```bash
minikube tunnel
```

---

#### Étape 8 — (Optionnel) Déployer le monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values k8s/monitoring/values.yaml
```

Ajouter les entrées DNS :

```bash
echo "$(minikube ip)  grafana.local prometheus.local" | sudo tee -a /etc/hosts
```

---

#### Accès aux services

| Service    | URL                                        | Identifiants       |
|------------|--------------------------------------------|--------------------|
| Application | http://pixel-war.local                   | —                  |
| Grafana    | http://grafana.local                       | admin / prom-operator |
| Prometheus | http://prometheus.local                    | —                  |

---

#### Commandes utiles

```bash
# État du cluster
kubectl get all -n pixel-war

# Logs backend
kubectl logs -n pixel-war -l app.kubernetes.io/component=backend -f

# Logs frontend
kubectl logs -n pixel-war -l app.kubernetes.io/component=frontend -f

# HPA (autoscaling)
kubectl get hpa -n pixel-war

# Supprimer le déploiement Helm
helm uninstall pixel-war -n pixel-war

# Supprimer l'infrastructure Terraform
cd infra/terraform && terraform destroy

# Arrêter Minikube
minikube stop

# Supprimer le cluster Minikube
minikube delete
```

---

## 🔧 CI/CD (GitHub Actions)

| Déclencheur | Pipeline |
|---|---|
| `pull_request` | Lint + Tests |
| `push main`    | Lint → Tests → Security → Build → Deploy staging → Smoke test |
| `tag v*.*.*`   | Idem + Deploy production + GitHub Release |

**Secrets GitHub requis :**

| Secret | Description |
|---|---|
| `KUBECONFIG` | kubeconfig base64-encodé |

---

## 🔒 Sécurité

- Conteneurs non-root (`runAsUser: 1001`)
- `readOnlyRootFilesystem: true` + `allowPrivilegeEscalation: false`
- NetworkPolicy : frontend → backend → PostgreSQL uniquement
- Secrets créés par Terraform (jamais dans les YAMLs commités)
- Scan Trivy (images) + Checkov (IaC) dans le pipeline

---

## 📊 Métriques Prometheus

| Métrique | Type | Description |
|---|---|---|
| `pixels_placed_total` | Counter | Pixels posés (label `color`) |
| `ws_connections_active` | Gauge | Connexions WebSocket actives |
| `api_request_duration_seconds` | Histogram | Latence API par route |
| `db_query_duration_seconds` | Histogram | Latence requêtes PostgreSQL |

---

## 🔄 Résilience

- 2 réplicas minimum (frontend + backend)
- HPA backend : 2 → 5 réplicas si CPU > 70%
- PodDisruptionBudget : `minAvailable: 1`
- RollingUpdate : `maxUnavailable: 0`, `maxSurge: 1`
- Rollback Helm automatique (`--atomic`)
- PostgreSQL sur PVC hostPath (données persistantes)

---

## 📜 Licence

MIT — ISIMA 2026
