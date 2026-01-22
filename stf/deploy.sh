#!/bin/bash

set -e

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher un message avec couleur
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Vérifier les prérequis
log_info "Vérification des prérequis..."

if ! command_exists kubectl; then
    log_error "kubectl n'est pas installé. Veuillez l'installer d'abord."
    exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "Impossible de se connecter au cluster Kubernetes."
    exit 1
fi

log_success "Prérequis OK"

# Fonction pour attendre qu'un pod soit prêt
wait_for_pod() {
    local label=$1
    local namespace=$2
    local timeout=${3:-300}

    log_info "Attente que les pods $label soient prêts (timeout: ${timeout}s)..."
    if kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" >/dev/null 2>&1; then
        log_success "Pods $label prêts"
        return 0
    else
        log_warning "Timeout atteint pour les pods $label, mais on continue..."
        return 0
    fi
}

# Fonction pour vérifier si un deployment existe
deployment_exists() {
    kubectl get deployment "$1" -n "$2" >/dev/null 2>&1
}

# Fonction pour vérifier si un daemonset existe
daemonset_exists() {
    kubectl get daemonset "$1" -n "$2" >/dev/null 2>&1
}

echo ""
log_info "======================================"
log_info "  Déploiement STF sur Kubernetes"
log_info "======================================"
echo ""

# Étape 1 : Namespace et ConfigMap
log_info "Étape 1/7 : Création du namespace et de la configuration..."
kubectl apply -f base/namespace.yaml
kubectl apply -f base/configmap.yaml
log_success "Namespace et ConfigMap créés"
sleep 2

# Étape 2 : RethinkDB
log_info "Étape 2/7 : Déploiement de RethinkDB..."
kubectl apply -f rethinkdb/pvc.yaml
kubectl apply -f rethinkdb/deployment.yaml
kubectl apply -f rethinkdb/service.yaml
wait_for_pod "app=rethinkdb" "stf" 300
log_success "RethinkDB déployé"
sleep 3

# Étape 3 : Triproxy
log_info "Étape 3/7 : Déploiement de Triproxy (hub ZeroMQ)..."
kubectl apply -f services/triproxy-deployment.yaml
kubectl apply -f services/triproxy-service.yaml
wait_for_pod "app=triproxy" "stf" 120
log_success "Triproxy déployé"
sleep 2

# Étape 4 : Services STF
log_info "Étape 4/7 : Déploiement des services STF..."

# Storage
log_info "  - Déploiement du Storage..."
kubectl apply -f services/storage-pvc.yaml
kubectl apply -f services/storage-deployment.yaml
kubectl apply -f services/storage-service.yaml

# Auth
log_info "  - Déploiement de l'Auth..."
kubectl apply -f services/auth-deployment.yaml
kubectl apply -f services/auth-service.yaml

# API
log_info "  - Déploiement de l'API..."
kubectl apply -f services/api-deployment.yaml
kubectl apply -f services/api-service.yaml

# Websocket
log_info "  - Déploiement du Websocket..."
kubectl apply -f services/websocket-deployment.yaml
kubectl apply -f services/websocket-service.yaml

# App
log_info "  - Déploiement de l'App..."
kubectl apply -f services/app-deployment.yaml
kubectl apply -f services/app-service.yaml

# Processor et Reaper
log_info "  - Déploiement du Processor et Reaper..."
kubectl apply -f services/processor-deployment.yaml
kubectl apply -f services/reaper-deployment.yaml

# Attendre que l'app soit prête
wait_for_pod "app=stf-app" "stf" 180
log_success "Services STF déployés"
sleep 2

# Étape 5 : Provider
log_info "Étape 5/7 : Déploiement du Provider (accès USB)..."
kubectl apply -f provider/daemonset.yaml
kubectl apply -f provider/service.yaml

log_info "  Attente du démarrage du Provider (15s)..."
sleep 15

# Vérifier que le provider a détecté des devices
log_info "  Vérification de la détection des devices Android..."
if kubectl get pods -n stf -l app=stf-provider | grep -q "Running"; then
    log_success "Provider déployé et en cours d'exécution"

    # Afficher les devices détectés
    log_info "  Devices Android détectés :"
    kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices 2>/dev/null || log_warning "  Impossible de lister les devices (vérifiez les logs du provider)"
else
    log_warning "Provider déployé mais pas encore en Running"
fi
sleep 2

# Étape 6 : Ingress
log_info "Étape 6/7 : Déploiement de l'Ingress..."
kubectl apply -f ingress/ingress.yaml
log_success "Ingress déployé"
sleep 2

# Étape 7 : Récapitulatif
echo ""
log_info "======================================"
log_success "  Déploiement STF terminé !"
log_info "======================================"
echo ""

# Afficher l'état des pods
log_info "État des pods dans le namespace stf :"
kubectl get pods -n stf

echo ""
log_info "État des services :"
kubectl get svc -n stf

echo ""
log_info "État de l'Ingress :"
kubectl get ingress -n stf

echo ""
log_info "======================================"
log_info "  Informations d'accès"
log_info "======================================"
echo ""
log_info "Interface Web : ${GREEN}http://stf.local${NC}"
log_info "API REST      : ${GREEN}http://stf.local/api/v1/${NC}"
log_info "Websocket     : ${GREEN}ws://stf.local/socket.io/${NC}"
echo ""
log_warning "Assurez-vous que 'stf.local' pointe vers l'IP de votre cluster"
log_warning "(ajoutez une entrée dans /etc/hosts ou configurez votre DNS)"
echo ""

# Vérifier les devices
log_info "======================================"
log_info "  Vérification des devices Android"
log_info "======================================"
echo ""

if kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices 2>/dev/null | grep -q "device$"; then
    log_success "Device(s) Android détecté(s) !"
    kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices 2>/dev/null
else
    log_warning "Aucun device Android détecté"
    echo ""
    log_info "Pour débugger :"
    log_info "  1. Vérifiez que votre appareil Android est connecté en USB"
    log_info "  2. Vérifiez que le mode développeur et le débogage USB sont activés"
    log_info "  3. Autorisez le débogage USB sur l'appareil (popup)"
    log_info "  4. Consultez les logs : kubectl logs -n stf -l app=stf-provider -c adb-server"
fi

echo ""
log_info "Pour voir les logs du provider STF :"
echo "  kubectl logs -n stf -l app=stf-provider -c provider"
echo ""
log_info "Pour désinstaller STF :"
echo "  kubectl delete namespace stf"
echo ""

log_success "Déploiement terminé avec succès !"
