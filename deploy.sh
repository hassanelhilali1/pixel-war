#!/usr/bin/env bash
# =============================================================================
# Pixel War 2026 — Script de déploiement automatisé 
# =============================================================================
# Usage :
#   ./deploy.sh              # déploiement complet (prérequis déjà installés)
#   ./deploy.sh --setup      # configure la machine hôte via Ansible puis déploie
#   ./deploy.sh --monitoring # déploiement complet + Prometheus/Grafana
#   ./deploy.sh --destroy    # supprime toute la stack
#
# Première utilisation sur une machine vierge :
#   ./deploy.sh --setup
#
# Prérequis (installés automatiquement avec --setup) :
#   ansible, docker, minikube, kubectl, helm, terraform
# =============================================================================
set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_step()    { echo -e "\n${BOLD}${BLUE}▶ $*${NC}"; }
die()         { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Variables ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING=false
DESTROY=false
SETUP=false
MINIKUBE_CPUS=4
MINIKUBE_MEMORY=6g
MINIKUBE_DRIVER=docker
MINIKUBE_WORKERS=2   # nombre de workers requis (hors control-plane)

# ── Arguments ─────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --monitoring) MONITORING=true ;;
    --destroy)    DESTROY=true ;;
    --setup)      SETUP=true ;;
    --help|-h)
      echo "Usage: $0 [--setup] [--monitoring] [--destroy]"
      echo "  --setup       Configure la machine hôte via Ansible (1ère utilisation)"
      echo "  --monitoring  Déploie aussi Prometheus + Grafana"
      echo "  --destroy     Supprime toute la stack"
      exit 0 ;;
    *) die "Argument inconnu : $arg" ;;
  esac
done

# ── Vérification des prérequis ────────────────────────────────────────────────
check_prereqs() {
  log_step "Vérification des prérequis"
  local missing=()
  for cmd in docker minikube kubectl helm terraform; do
    if command -v "$cmd" &>/dev/null; then
      log_success "$cmd $(${cmd} version --short 2>/dev/null | head -1 || true)"
    else
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Outils manquants : ${missing[*]}\nRelancez avec : ./deploy.sh --setup"
  fi
}

# ── Étape 0 : Ansible (configuration machine hôte) ──────────────────────────
run_ansible() {
  log_step "Étape 0 — Configuration de la machine hôte (Ansible)"

  if ! command -v ansible-playbook &>/dev/null; then
    log_info "Installation d'Ansible..."
    sudo apt-get update -q
    sudo apt-get install -y ansible
  fi

  log_info "Lancement du playbook Ansible..."
  ansible-playbook \
    -i "$SCRIPT_DIR/infra/ansible/inventory/localhost.yml" \
    "$SCRIPT_DIR/infra/ansible/playbook.yml"

  log_success "Machine hôte configurée"
}

# ── Destroy ───────────────────────────────────────────────────────────────────
destroy_all() {
  log_step "Suppression de la stack"
  log_warn "Suppression du déploiement Helm..."
  helm uninstall pixel-war -n pixel-war 2>/dev/null || true

  if [[ "$MONITORING" == true ]]; then
    log_warn "Suppression du monitoring..."
    helm uninstall monitoring -n monitoring 2>/dev/null || true
  fi

  log_warn "Suppression de l'infrastructure Terraform..."
  cd "$SCRIPT_DIR/infra/terraform"
  terraform destroy -auto-approve 2>/dev/null || true

  log_warn "Arrêt de Minikube..."
  minikube stop || true

  log_success "Stack supprimée."
  exit 0
}

# ── Étape 1 : Minikube ────────────────────────────────────────────────────────
start_minikube() {
  log_step "Étape 1 — Démarrage de Minikube"
  local status
  status=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")

  if [[ "$status" == "Running" ]]; then
    log_success "Minikube déjà en cours d'exécution"
  else
    log_info "Démarrage de Minikube (cpus=$MINIKUBE_CPUS, memory=$MINIKUBE_MEMORY, nodes=$((MINIKUBE_WORKERS+1)))..."
    minikube start \
      --cpus="$MINIKUBE_CPUS" \
      --memory="$MINIKUBE_MEMORY" \
      --driver="$MINIKUBE_DRIVER" \
      --nodes="$((MINIKUBE_WORKERS + 1))"
    log_success "Minikube démarré"
  fi

  # ── Vérification et ajout des workers manquants ───────────────────────────
  local current_workers
  current_workers=$(kubectl get nodes --no-headers 2>/dev/null \
    | grep -v "control-plane" | wc -l | tr -d ' ' || true)

  if [[ "$current_workers" -lt "$MINIKUBE_WORKERS" ]]; then
    local to_add=$(( MINIKUBE_WORKERS - current_workers ))
    log_info "$current_workers worker(s) présent(s), ajout de $to_add worker(s) manquant(s)..."
    for ((i=1; i<=to_add; i++)); do
      log_info "Ajout du worker $i/$to_add..."
      minikube node add --worker
      log_success "Worker $i ajouté"
    done
  else
    log_success "$current_workers worker(s) présent(s) — aucun ajout nécessaire"
  fi

  log_info "Activation des addons..."
  minikube addons enable ingress        2>/dev/null || true
  minikube addons enable metrics-server 2>/dev/null || true
  log_success "Addons activés (ingress, metrics-server)"

  log_info "Nœuds du cluster :"
  kubectl get nodes
}

# ── Étape 2 : Build des images dans Minikube ─────────────────────────────────
build_images() {
  log_step "Étape 2 — Build des images Docker"
  # Garantir qu'on utilise le Docker SYSTÈME (pas le daemon interne de Minikube).
  # Si l'utilisateur avait fait `eval $(minikube docker-env)` dans son shell,
  # DOCKER_HOST pointe vers Minikube (API 1.43). docker build fonctionne grâce
  # à BuildKit (gRPC, négocie la version), mais docker save utilise l'API REST
  # classique et échoue avec "client version 1.52 is too new".
  eval "$(minikube docker-env -u)" 2>/dev/null || true
  unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH DOCKER_API_VERSION

  log_info "Build backend (Docker système)..."
  docker build -t pixel-war-backend:latest \
    "$SCRIPT_DIR/app/backend" \
    --target production \
    -q
  log_success "pixel-war-backend:latest buildée"

  log_info "Build frontend (Docker système)..."
  docker build -t pixel-war-frontend:latest \
    "$SCRIPT_DIR/app/frontend" \
    --target production \
    --build-arg VITE_GRID_SIZE=50 \
    -q
  log_success "pixel-war-frontend:latest buildée"

  log_info "Chargement des images dans Minikube (via tar)..."
  docker save pixel-war-backend:latest  -o /tmp/pixel-war-backend.tar
  minikube image load /tmp/pixel-war-backend.tar
  rm -f /tmp/pixel-war-backend.tar
  log_success "pixel-war-backend:latest chargée dans Minikube"

  docker save pixel-war-frontend:latest -o /tmp/pixel-war-frontend.tar
  minikube image load /tmp/pixel-war-frontend.tar
  rm -f /tmp/pixel-war-frontend.tar
  log_success "pixel-war-frontend:latest chargée dans Minikube"
}

# ── Étape 3 : Terraform ───────────────────────────────────────────────────────
run_terraform() {
  log_step "Étape 3 — Provisioning Terraform"
  cd "$SCRIPT_DIR/infra/terraform"

  [[ -f terraform.tfvars ]] || die "Fichier terraform.tfvars introuvable.\nCopiez terraform.tfvars.example → terraform.tfvars et renseignez db_password."

  log_info "terraform init..."
  terraform init -upgrade -input=false 2>&1 | grep -E "^(Initializing|Terraform|─)" || true

  log_info "terraform apply..."
  terraform apply -auto-approve -input=false
  log_success "Infrastructure provisionnée"

  cd "$SCRIPT_DIR"
}

# ── Étape 4 : Helm deploy ─────────────────────────────────────────────────────
deploy_helm() {
  log_step "Étape 4 — Déploiement Helm"
  helm upgrade --install pixel-war "$SCRIPT_DIR/k8s/charts/pixel-war/" \
    --namespace pixel-war \
    --values "$SCRIPT_DIR/k8s/charts/pixel-war/values.yaml" \
    --wait \
    --timeout 8m \
    --atomic

  log_success "Application déployée"

  log_info "État des pods :"
  kubectl get pods -n pixel-war
}

# ── Étape 5 : DNS /etc/hosts ──────────────────────────────────────────────────
setup_dns() {
  log_step "Étape 5 — Configuration DNS locale"
  local minikube_ip
  minikube_ip=$(minikube ip)

  local entries=("pixel-war.local")
  [[ "$MONITORING" == true ]] && entries+=("grafana.local" "prometheus.local")

  for host in "${entries[@]}"; do
    if grep -q "$host" /etc/hosts 2>/dev/null; then
      log_success "$host déjà dans /etc/hosts"
    else
      echo "$minikube_ip  $host" | sudo tee -a /etc/hosts > /dev/null
      log_success "$minikube_ip  $host → ajouté à /etc/hosts"
    fi
  done
}

# ── Étape 6 : Monitoring ──────────────────────────────────────────────────────
deploy_monitoring() {
  log_step "Étape 6 — Déploiement Monitoring (Prometheus + Grafana)"

  if ! helm repo list 2>/dev/null | grep -q "prometheus-community"; then
    log_info "Ajout du repo prometheus-community..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  fi
  helm repo update prometheus-community

  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --values "$SCRIPT_DIR/k8s/monitoring/values.yaml" \
    --wait \
    --timeout 10m
  log_success "Monitoring déployé"
}

# ── Étape 7 : Tunnel & résumé ─────────────────────────────────────────────────
start_tunnel() {
  log_step "Étape 7 — Lancement du tunnel Minikube"
  log_info "Démarrage en arrière-plan (PID stocké dans /tmp/minikube-tunnel.pid)..."

  # Tuer un tunnel précédent si existant
  if [[ -f /tmp/minikube-tunnel.pid ]]; then
    local old_pid
    old_pid=$(cat /tmp/minikube-tunnel.pid)
    kill "$old_pid" 2>/dev/null || true
  fi

  sudo minikube tunnel &
  echo $! > /tmp/minikube-tunnel.pid
  sleep 3
  log_success "Tunnel actif (PID=$(cat /tmp/minikube-tunnel.pid))"
}

print_summary() {
  echo -e "\n${BOLD}${GREEN}════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}    Déploiement terminé avec succès !${NC}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
  echo -e ""
  echo -e "    Application  →  ${BOLD}http://pixel-war.local${NC}"
  echo -e "    API Health   →  ${BOLD}http://pixel-war.local/api/health${NC}"
  echo -e "    Métriques    →  ${BOLD}http://pixel-war.local/metrics${NC}"
  if [[ "$MONITORING" == true ]]; then
    echo -e "    Grafana      →  ${BOLD}http://grafana.local${NC}  (admin / prom-operator)"
    echo -e "    Prometheus   →  ${BOLD}http://prometheus.local${NC}"
  fi
  echo -e ""
  echo -e "  Pour arrêter le tunnel : kill \$(cat /tmp/minikube-tunnel.pid)"
  echo -e "  Pour tout supprimer   : ${BOLD}./deploy.sh --destroy${NC}"
  echo -e "  Sur une nouvelle machine : ${BOLD}./deploy.sh --setup${NC}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {


  if [[ "$DESTROY" == true ]]; then destroy_all; fi
  if [[ "$SETUP"   == true ]]; then run_ansible; fi

  check_prereqs
  start_minikube
  build_images
  run_terraform
  deploy_helm
  setup_dns
  if [[ "$MONITORING" == true ]]; then deploy_monitoring; fi
  start_tunnel
  print_summary
}

main
