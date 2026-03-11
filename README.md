# Pixel War - Projet DevOps ISIMA

Projet de r/place simplifié pour le cours de DevOps.

## Architecture

```
Navigateur  -->  Ingress Nginx  -->  Frontend (React/Nginx)
                                          |
                                     Backend (Node.js/Express/socket.io)
                                          |
                                     PostgreSQL
                                          |
                                     Prometheus + Grafana (monitoring)
```

Tout tourne dans le namespace `pixel-war` sur Minikube.

## Stack technique

- **Frontend** : React 18, Vite, socket.io-client, Nginx
- **Backend** : Node.js 20, Express, socket.io, prom-client
- **Base de données** : PostgreSQL 16
- **Conteneurisation** : Docker (multi-stage build)
- **Orchestration** : Kubernetes (Minikube)
- **Helm** : chart custom dans `k8s/charts/pixel-war/`
- **IaC** : Terraform (namespace, secrets, PostgreSQL)
- **Config machine** : Ansible (installation des outils)
- **CI/CD** : GitHub Actions
- **Monitoring** : Prometheus + Grafana

## Structure du projet

```
pixel-war/
├── app/
│   ├── backend/          # API Node.js
│   └── frontend/         # App React
├── infra/
│   ├── terraform/        # IaC Kubernetes
│   └── ansible/          # Config machine
├── k8s/
│   ├── charts/pixel-war/ # Chart Helm
│   └── monitoring/       # Config Prometheus/Grafana
├── .github/workflows/    # Pipeline CI/CD
├── deploy.sh             # Script de deploiement auto
└── docker-compose.yml    # Dev local
```

---

## Deploiement rapide

### Docker Compose (dev local)

```bash
git clone https://github.com/hassanelhilali1/pixel-war
cd pixel-war
docker compose up --build
```

L'app sera dispo sur http://localhost

```bash
docker compose down -v    # pour tout arreter et supprimer les volumes
```

### Kubernetes (Minikube)

Un script fait tout automatiquement :

```bash
./deploy.sh              # deploiement complet
./deploy.sh --monitoring # avec prometheus + grafana
./deploy.sh --destroy    # tout supprimer
```

**Prerequis :** configurer la machine une fois avec Ansible :

```bash
cd infra/ansible
ansible-playbook -i inventory/localhost.yml playbook.yml --ask-become-pass
```

---

## Deploiement manuel

Si vous voulez pas utiliser `deploy.sh`, voila les etapes :

### 1. Configurer la machine (Ansible)

```bash
cd infra/ansible
ansible-playbook -i inventory/localhost.yml playbook.yml --ask-become-pass
```

Ca installe Docker, kubectl, Helm, Minikube et Terraform.

### 2. Demarrer Minikube

```bash
minikube start --cpus=4 --memory=6g --driver=docker
minikube addons enable ingress
minikube addons enable metrics-server
```

### 3. Builder les images

```bash
eval $(minikube docker-env)
docker build -t pixel-war-backend:latest  ./app/backend  --target production
docker build -t pixel-war-frontend:latest ./app/frontend --target production --build-arg VITE_GRID_SIZE=50
```

### 4. Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# editer terraform.tfvars avec le mot de passe de la BDD
terraform init
terraform apply
```

### 5. Helm

```bash
helm upgrade --install pixel-war k8s/charts/pixel-war/ \
  --namespace pixel-war \
  --values k8s/charts/pixel-war/values.yaml \
  --wait --atomic --timeout 5m
```

### 6. DNS et tunnel

```bash
echo "$(minikube ip)  pixel-war.local" | sudo tee -a /etc/hosts
minikube tunnel   # laisser tourner
```

### 7. Monitoring (optionnel)

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

## URLs

| Service | URL | Login |
|---|---|---|
| Application | http://pixel-war.local | - |
| Grafana | http://grafana.local | admin / prom-operator |
| Prometheus | http://prometheus.local | - |

## Commandes utiles

```bash
kubectl get all -n pixel-war              # voir tout
kubectl logs -n pixel-war -l app.kubernetes.io/component=backend -f   # logs backend
kubectl get hpa -n pixel-war              # autoscaling
helm rollback pixel-war -n pixel-war      # rollback
helm uninstall pixel-war -n pixel-war     # supprimer
minikube stop                             # arreter minikube
```

## CI/CD

Pipeline GitHub Actions avec 5 jobs :

1. **Lint** : ESLint + hadolint + yamllint
2. **Tests** : Jest avec couverture de code
3. **Security** : Checkov (Terraform, K8s) + Trivy (images Docker)
4. **Build** : Build et push des images Docker sur GHCR
5. **Deploy** : Helm upgrade + smoke tests

Se declenche sur push/PR vers main.

## Securite

- Conteneurs non-root (`runAsUser: 1001`)
- Filesystem en lecture seule
- Pas d'escalade de privileges
- NetworkPolicy (frontend -> backend -> postgres seulement)
- Secrets geres par Terraform (pas dans le repo)
- Scan Trivy + Checkov dans la CI

## Monitoring

4 metriques Prometheus custom :
- `pixels_placed_total` : nombre de pixels poses
- `ws_connections_active` : connexions websocket
- `api_request_duration_seconds` : latence des requetes
- `db_query_duration_seconds` : latence des requetes BDD

Dashboard Grafana provisionne automatiquement.

## Resilience

- 2 replicas min (frontend + backend)
- HPA : scale de 2 a 5 pods si CPU > 70%
- PodDisruptionBudget : au moins 1 pod toujours dispo
- Rolling update sans downtime
- Helm `--atomic` : rollback auto si le deploy echoue
- Probes readiness + liveness
