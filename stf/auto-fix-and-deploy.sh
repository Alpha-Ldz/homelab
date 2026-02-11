
# Script automatique qui tente toutes les solutions dans l'ordre

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
log_info "=========================================="
log_info "  Fix et Déploiement automatique STF"
log_info "=========================================="
echo ""

IMAGES_TO_TRY=(
    "devicefarmer/stf:latest"
    "devicefarmer/stf:1.5.0"
)

SUCCESS=0

for IMAGE in "${IMAGES_TO_TRY[@]}"; do
    log_info "Tentative avec $IMAGE..."

    # Mettre à jour les manifests
    cd docker
    ./update-manifests.sh "$IMAGE" >/dev/null 2>&1
    cd ..

    # Nettoyer le namespace
    log_info "Nettoyage du namespace stf..."
    kubectl delete namespace stf --wait=true >/dev/null 2>&1 || true
    sleep 5

    # Déployer
    log_info "Déploiement avec $IMAGE..."
    ./deploy.sh

    # Attendre un peu
    sleep 30

    # Vérifier si ça fonctionne
    log_info "Vérification du déploiement..."
    ERROR_COUNT=$(kubectl logs -n stf -l app=stf-app --tail=50 2>/dev/null | grep -c "exec format error" || echo "0")

    if [ "$ERROR_COUNT" -eq 0 ]; then
        log_success "Déploiement réussi avec $IMAGE !"
        SUCCESS=1
        break
    else
        log_error "$IMAGE ne fonctionne pas (exec format error)"
        log_info "Tentative suivante..."
    fi

    echo ""
done

echo ""
log_info "=========================================="

if [ $SUCCESS -eq 1 ]; then
    log_success "STF déployé avec succès !"
    echo ""
    log_info "Accédez à l'interface : http://stf.local"
    log_info "Vérifiez les pods : kubectl get pods -n stf"
    log_info "Vérifiez les devices : make devices"
else
    log_error "Aucune image pré-buildée ne fonctionne"
    echo ""
    log_warning "Vous devrez builder STF pour ARM64 localement"
    log_info "Lancez : ./fix-arm64.sh et choisissez l'option 2"
    log_info "Temps estimé : 30-60 minutes"
fi

echo ""
log_info "=========================================="
echo ""
