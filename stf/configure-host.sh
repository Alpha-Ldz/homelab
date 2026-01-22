
# Script de configuration du host pour STF

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
log_info "=========================================="
log_info "  Configuration du host pour STF"
log_info "=========================================="
echo ""

# 1. Vérifier que le device USB est présent
log_info "1. Vérification de la détection USB..."
if lsusb | grep -i "samsung\|galaxy" > /dev/null; then
    DEVICE=$(lsusb | grep -i "samsung\|galaxy")
    log_success "Device Samsung détecté :"
    echo "   $DEVICE"
else
    log_warning "Aucun device Samsung détecté via lsusb"
    log_warning "Assurez-vous que votre appareil est bien connecté en USB"
fi
echo ""

# 2. Vérifier les permissions USB
log_info "2. Vérification des permissions USB..."
if [ -d "/dev/bus/usb" ]; then
    log_success "Répertoire /dev/bus/usb existe"
    log_info "Permissions actuelles :"
    ls -la /dev/bus/usb/004/002 2>/dev/null || ls -la /dev/bus/usb/004/ 2>/dev/null || log_warning "Device USB non trouvé dans /dev/bus/usb"
else
    log_warning "/dev/bus/usb n'existe pas"
fi
echo ""

# 3. Configuration DNS/hosts
log_info "3. Configuration DNS pour stf.local..."
CLUSTER_IP=$(hostname -I | awk '{print $1}')
log_info "IP détectée du serveur : $CLUSTER_IP"

if grep -q "stf.local" /etc/hosts; then
    log_warning "Entrée stf.local déjà présente dans /etc/hosts :"
    grep "stf.local" /etc/hosts
else
    log_info "Ajout de stf.local dans /etc/hosts..."
    echo "$CLUSTER_IP  stf.local" | sudo tee -a /etc/hosts
    log_success "Entrée ajoutée : $CLUSTER_IP  stf.local"
fi
echo ""

# 4. Vérifier Kubernetes
log_info "4. Vérification du cluster Kubernetes..."
if command -v kubectl > /dev/null; then
    if kubectl cluster-info > /dev/null 2>&1; then
        log_success "Cluster Kubernetes accessible"
        log_info "Nodes disponibles :"
        kubectl get nodes
    else
        log_warning "kubectl installé mais cluster non accessible"
    fi
else
    log_warning "kubectl n'est pas installé"
fi
echo ""

# 5. Vérifier l'ingress controller
log_info "5. Vérification de l'ingress controller..."
if kubectl get pods -n ingress-nginx > /dev/null 2>&1; then
    INGRESS_PODS=$(kubectl get pods -n ingress-nginx | grep -c "Running" || echo "0")
    if [ "$INGRESS_PODS" -gt 0 ]; then
        log_success "Nginx Ingress Controller actif ($INGRESS_PODS pods)"
    else
        log_warning "Nginx Ingress Controller installé mais aucun pod en Running"
    fi
else
    log_warning "Nginx Ingress Controller non détecté"
    log_info "Pour l'installer :"
    echo "   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml"
fi
echo ""

# 6. Résumé
log_info "=========================================="
log_info "  Résumé de la configuration"
log_info "=========================================="
echo ""
log_info "Device USB        : $(lsusb | grep -i samsung | awk '{print $7, $8, $9, $10}' || echo 'Non détecté')"
log_info "URL STF           : http://stf.local"
log_info "IP du cluster     : $CLUSTER_IP"
log_info "Cluster K8s       : $(kubectl cluster-info > /dev/null 2>&1 && echo 'OK' || echo 'KO')"
echo ""

log_info "Prochaines étapes :"
echo "  1. Vérifiez que le débogage USB est activé sur votre Samsung"
echo "  2. Lancez le déploiement : ./deploy.sh"
echo "  3. Surveillez les logs : make logs-provider"
echo "  4. Accédez à l'interface : http://stf.local"
echo ""
