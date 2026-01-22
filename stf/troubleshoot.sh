#!/bin/bash

# Script de diagnostic pour STF
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
log_info "=========================================="
log_info "  STF - Diagnostic de troubleshooting"
log_info "=========================================="
echo ""

# 1. Vérifier kubectl
log_info "1. Vérification de kubectl..."
if command -v kubectl >/dev/null 2>&1; then
    log_success "kubectl est installé"
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Connexion au cluster OK"
    else
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
else
    log_error "kubectl n'est pas installé"
    exit 1
fi
echo ""

# 2. Vérifier le namespace
log_info "2. Vérification du namespace stf..."
if kubectl get namespace stf >/dev/null 2>&1; then
    log_success "Namespace 'stf' existe"
else
    log_error "Namespace 'stf' n'existe pas. Déployez d'abord avec ./deploy.sh"
    exit 1
fi
echo ""

# 3. État des pods
log_info "3. État des pods dans le namespace stf..."
echo ""
kubectl get pods -n stf
echo ""

FAILED_PODS=$(kubectl get pods -n stf --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "$FAILED_PODS" -gt 0 ]; then
    log_warning "$FAILED_PODS pod(s) ne sont pas en état Running"
    log_info "Pods problématiques :"
    kubectl get pods -n stf --field-selector=status.phase!=Running,status.phase!=Succeeded
else
    log_success "Tous les pods sont en état Running"
fi
echo ""

# 4. Vérifier RethinkDB
log_info "4. Vérification de RethinkDB..."
if kubectl get pods -n stf -l app=rethinkdb | grep -q "Running"; then
    log_success "RethinkDB est en Running"

    # Vérifier les logs pour erreurs
    RETHINK_ERRORS=$(kubectl logs -n stf -l app=rethinkdb --tail=50 2>/dev/null | grep -i "error\|fatal\|failed" | wc -l)
    if [ "$RETHINK_ERRORS" -gt 0 ]; then
        log_warning "Erreurs détectées dans les logs RethinkDB :"
        kubectl logs -n stf -l app=rethinkdb --tail=50 | grep -i "error\|fatal\|failed"
    else
        log_success "Pas d'erreurs dans les logs RethinkDB"
    fi
else
    log_error "RethinkDB n'est pas en Running"
fi
echo ""

# 5. Vérifier Triproxy
log_info "5. Vérification de Triproxy..."
if kubectl get pods -n stf -l app=triproxy | grep -q "Running"; then
    log_success "Triproxy est en Running"
else
    log_error "Triproxy n'est pas en Running - cela bloquera la communication entre services"
fi
echo ""

# 6. Vérifier le Provider
log_info "6. Vérification du Provider (accès USB)..."
if kubectl get pods -n stf -l app=stf-provider | grep -q "Running"; then
    log_success "Provider est en Running"

    log_info "Devices Android détectés par ADB :"
    if kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices 2>/dev/null | grep -q "device$"; then
        kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices 2>/dev/null
        log_success "Au moins un device Android détecté"
    else
        log_warning "Aucun device Android détecté"
        echo ""
        log_info "Vérifications USB sur le host :"
        echo ""

        # Vérifier USB sur le host
        log_info "Périphériques USB Android connectés :"
        if lsusb | grep -i "android\|google\|samsung\|xiaomi\|oppo\|huawei" >/dev/null 2>&1; then
            lsusb | grep -i "android\|google\|samsung\|xiaomi\|oppo\|huawei"
            log_success "Device USB Android détecté sur le host"
        else
            log_warning "Aucun device Android trouvé via lsusb sur le host"
        fi

        echo ""
        log_info "Suggestions :"
        echo "  - Vérifiez que l'appareil Android est bien connecté en USB"
        echo "  - Activez le mode développeur sur l'appareil"
        echo "  - Activez le débogage USB dans les options développeur"
        echo "  - Autorisez le débogage USB sur l'appareil (popup)"
        echo "  - Essayez un autre câble USB (certains ne transmettent que la charge)"
        echo "  - Redémarrez le provider : make restart-provider"
    fi
else
    log_error "Provider n'est pas en Running"
fi
echo ""

# 7. Vérifier l'App
log_info "7. Vérification de l'App (interface web)..."
if kubectl get pods -n stf -l app=stf-app | grep -q "Running"; then
    log_success "App est en Running"
else
    log_error "App n'est pas en Running"
fi
echo ""

# 8. Vérifier l'Ingress
log_info "8. Vérification de l'Ingress..."
if kubectl get ingress -n stf stf-ingress >/dev/null 2>&1; then
    log_success "Ingress existe"

    INGRESS_IP=$(kubectl get ingress -n stf stf-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$INGRESS_IP" ]; then
        log_success "Ingress a une IP : $INGRESS_IP"
    else
        log_warning "Ingress n'a pas encore d'IP assignée"
    fi

    # Vérifier nginx ingress controller
    if kubectl get pods -n ingress-nginx | grep -q "Running"; then
        log_success "Nginx Ingress Controller est actif"
    else
        log_warning "Nginx Ingress Controller semble absent ou arrêté"
    fi
else
    log_error "Ingress n'existe pas"
fi
echo ""

# 9. Vérifier les Services
log_info "9. Vérification des Services..."
SERVICES=("rethinkdb" "triproxy" "app" "auth" "api" "websocket" "storage" "provider")
for svc in "${SERVICES[@]}"; do
    if kubectl get svc -n stf "$svc" >/dev/null 2>&1; then
        log_success "Service '$svc' existe"
    else
        log_warning "Service '$svc' n'existe pas"
    fi
done
echo ""

# 10. Vérifier les PVC
log_info "10. Vérification des PersistentVolumeClaims..."
kubectl get pvc -n stf
echo ""
PENDING_PVC=$(kubectl get pvc -n stf --field-selector=status.phase!=Bound --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PVC" -gt 0 ]; then
    log_warning "$PENDING_PVC PVC ne sont pas en état Bound"
else
    log_success "Tous les PVC sont Bound"
fi
echo ""

# 11. Test de connectivité réseau
log_info "11. Test de connectivité entre services..."
if kubectl get pods -n stf -l app=stf-app | grep -q "Running"; then
    log_info "Test de connexion depuis l'app vers RethinkDB..."
    if kubectl exec -n stf -l app=stf-app -- nc -zv rethinkdb 28015 2>&1 | grep -q "succeeded\|open"; then
        log_success "L'app peut joindre RethinkDB"
    else
        log_warning "L'app ne peut pas joindre RethinkDB"
    fi

    log_info "Test de connexion depuis l'app vers Triproxy..."
    if kubectl exec -n stf -l app=stf-app -- nc -zv triproxy 7150 2>&1 | grep -q "succeeded\|open"; then
        log_success "L'app peut joindre Triproxy"
    else
        log_warning "L'app ne peut pas joindre Triproxy"
    fi
fi
echo ""

# 12. Vérifier les ressources système
log_info "12. Ressources système (nodes)..."
kubectl top nodes 2>/dev/null || log_warning "metrics-server non installé, impossible d'afficher les métriques"
echo ""

# 13. Events récents
log_info "13. Events récents (potentiellement problématiques)..."
kubectl get events -n stf --sort-by='.lastTimestamp' | tail -20
echo ""

# 14. Récapitulatif
echo ""
log_info "=========================================="
log_info "  Récapitulatif"
log_info "=========================================="
echo ""

log_info "Commandes utiles pour investiguer :"
echo ""
echo "  # Voir les logs d'un pod spécifique"
echo "  kubectl logs -n stf <pod-name> -f"
echo ""
echo "  # Voir les logs du provider"
echo "  kubectl logs -n stf -l app=stf-provider -c provider -f"
echo ""
echo "  # Voir les logs du serveur ADB"
echo "  kubectl logs -n stf -l app=stf-provider -c adb-server -f"
echo ""
echo "  # Décrire un pod pour voir les events"
echo "  kubectl describe pod -n stf <pod-name>"
echo ""
echo "  # Redémarrer le provider si device non détecté"
echo "  make restart-provider"
echo "  # ou"
echo "  kubectl rollout restart daemonset stf-provider -n stf"
echo ""
echo "  # Accéder à l'interface web"
echo "  http://stf.local"
echo ""

log_info "=========================================="
log_info "  Diagnostic terminé"
log_info "=========================================="
